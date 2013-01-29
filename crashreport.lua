#!/usr/bin/env lua
-- -*- lua -*-
-- copyright: 2012 Appwill Inc.
-- author : jorsion
--

local cjson = require("cjson")
local redis = require("resty.redis")
local pgutils = require("pgutils")

local crash_shared_dict = ngx.shared.crash_shared_dict

local tonumber = tonumber
local tostring = tostring
local ipairs = ipairs
local pairs = pairs
local type = type

local math_huge = math.huge
local math_min = math.min

local string_format = string.format
local string_match = string.match

local table_insert = table.insert
local table_concat = table.concat

local stringutils = require("stringutils")
local cal_edit_dist = stringutils.cal_edit_dist
local refine_crash_info = stringutils.refine_crash_info

local cjson_encode = cjson.encode
local cjson_decode = cjson.decode

local pg_query = pgutils.pg_query
local pg_select = pgutils.pg_select
local get_number_by_row = pgutils.get_number_by_row
local row2list_entity = pgutils.row2list_entity

local null = ngx.null

local logger = logger
local os = os

local data_key = "data"
local crash_list_key = "crash_report_list"
local crash_num_key = "crash_num"
local crash_hashmap_key = "crash_hashmap"
local crash_app_set_key = "crash_app_set"
local crash_normalizing_key = "crash_normalizing"
local crash_type_id_field = "crash_type_id"
local edit_dist_threshold = 1

module("crashreport")

local function begin_normalize()
    local flag = crash_shared_dict:get(crash_normalizing_key)
    if flag == nil then
        crash_shared_dict:set(crash_normalizing_key, "1")
        return true
    end

    if tonumber(flag) == 1 then
        return false
    else
        crash_shared_dict:set(crash_normalizing_key, "1")
        return true
    end
end

local function end_normalize()
    local flag = crash_shared_dict:get(crash_normalizing_key)
    if flag == nil then
        return
    end

    if(tonumber(flag) == 0) then
        return 
    else
        crash_shared_dict:set(crash_normalizing_key, "0")
    end
end

local function write_data_into_db(tablename, data)
    if tablename == nil or data == nil then return end
    if type(data) ~= "table" then return end

    local fields = {}
    local values = {}
    for k, v in pairs(data) do
        table_insert(fields, k)
        table_insert(values, v)
    end
    local fields_string = table_concat(fields, ", ")
    local values_string = table_concat(values, "', '")
    values_string = string_format("'%s'", values_string)

    local query_sql = string_format("insert into %s ( %s ) values ( %s )", tablename, fields_string, values_string)
    logger:debug("Query string is: %s", query_sql)
    local ret = pg_query(query_sql)
    if not ret then
        logger:e("Failed to insert data to table crash_report")
		return 0
    end
	return 1
end

local function update_redis_db(red,  data)
    if data == nil then return 0 end

	local app_name = data["app"]
	local app_version = data["version"]

	red:sadd(crash_app_set_key, app_name)
	red:sadd(app_name, app_version)

    local crash_statis_hash_key = string_format("%s:%s", app_name, app_version)
    local crash_statis_field = data["time"]

    red:hincrby(crash_statis_hash_key, crash_statis_field, 1)
end

local function do_normalize(red)
    while true do
        local crash_data = red:rpop(crash_list_key)
		logger:debug(crash_data)
		if crash_data == null then break end

        local crash_info = cjson_decode(crash_data)
        local data = crash_info[data_key]

        local crash_num = red:get(crash_num_key)
        if crash_num == null then
            crash_num = 1
            red:set(crash_num_key, tostring(crash_num))
            red:hset(crash_hashmap_key, tostring(crash_num), data)
        else
            crash_num = tonumber(crash_num)
        end
    
        local min_dist = math_huge
        for i = 1, crash_num do
            local current_crash_info = red:hget(crash_hashmap_key, tostring(i))
            min_dist = math_min(min_dist, cal_edit_dist(data, current_crash_info))
        end

        if min_dist > edit_dist_threshold then
            crash_num = red:incr(crash_num_key)
            red:hset(crash_hashmap_key, crash_num, data)
            local crashdata = {}
            crashdata["id"] = crash_num
            crashdata["crash_desc"] = data
            local ret = write_data_into_db("crash_type", crashdata)
            if ret == 0 then
                logger:e("Failed to insert data to %s table", "crash_type")
            end
        end

        crash_info[crash_type_id_field] = tostring(crash_num)
        local ret = write_data_into_db("crash_report", crash_info)
		if ret == 0 then
            logger:e("Failed to insert data to %s table", "crash_report")
        else
            update_redis_db(data)
        end
    end
end

local function normalize(red)
    if(begin_normalize()) then
        do_normalize(red)
        end_normalize()
    end
end

local function connect_to_redis(ip, port)
	local red = redis:new()
    local ok, err = red:connect(ip, port)
    if not ok then
        logger:e("Failed to connect Redis: %s", error)
        return nil
    end
    ok, err = red:set_keepalive(0, 100)
    if not ok then
        logger:e("Failed to set keepalive: ", err)
		red:close()
		return nil
    end

	return red
end

function save(req, resp)
    local args
    if req.method == 'GET' then
        args = req.uri_args
    elseif req.method == 'POST' then
        req:read_body()
        args = req.post_args
    end
    
    if(args == nil) then return end
  
    -- local red = connect_to_redis("127.0.0.1", 6379)  
    local red = redis:new()
    red:set_timeout(1000)
    local ok, err = red:connect("127.0.0.1", 6379)
    if not ok then
        logger:e("Failed to connect Redis: %s", error)
        return
    end

    local n = red:lpush(crash_list_key, cjson_encode(args))
	logger:e("pushed num: %d", n)

    resp:write("OK")

    resp:finish()

    normalize(red)

    ok, err = red:set_keepalive(0, 100)
    if not ok then
        logger:e("Failed to set keepalive: ", err)
    end
end

local function select_from_db(sql)
    local ret = pg_query(sql)
    if not ret then
        logger:e("Failed to insert data to table crash_report")
        return ""
    end
    return cjson_encode(ret.resultset)
end

local function dates_included(start_date, end_date)
    local ret = {}
	local delta = 86400
	y_start, m_start, d_start = string_match(start_date, "(%d+)-(%d+)-(%d+)")
	y_end, m_end, d_end = string_match(end_date, "(%d+)-(%d+)-(%d+)")
	
	local start_date = os.time{year = y_start, month = m_start, day = d_start}
	local end_date = os.time{year = y_end, month = m_end, day = d_end}
	if end_date < start_date then
		start_date, end_date = end_date, start_date
	end	
	
	for d = start_date, end_date, delta do
		local date_table = os.date("*t", d)
		table_insert(ret, string_format("%d-%d-%d", date_table.year, date_table.month, date_table.day))
	end

	return ret
end

local function app_versions(red, app)
	return red:smembers(app)
end

local function statistics_single_from_db(red, start_date, end_date, app, version)
	local result = {}
	local versions = version and app_versions(red, app) or {version}
	local dates = dates_included(start_date, end_date)
	for _, ver in ipairs(versions) do
		local app_version = string_format("%s:%s", app, var)
		local sums = red:hmget(app_version, unpack(dates))
		local sum = 0
		for _, _sum in ipairs(sums) do
			sum = sum + _sum
		end
		table_insert(result, {app = app, version = ver, conut = count})
	end

	return cjson_encode(result)
end

local function statistics_all_from_db(red, start_date, end_date)
	local result = {}
	local app_versions = {}
	local dates = dates_included(start_date, end_date)
	local apps = red:smembers(crash_app_set_key)
	for _, app_name in ipairs(apps) do
		local versions = red:smember(app_name)
		for _, ver in ipairs(versions) do
			local app_version = string_format("%s:%s", app_name, ver)
			local sums = red:hmget(app_version, unpack(dates))
			local sum = 0
			for _, _sum in ipairs(sums) do
				sum = sum + _sum
			end
			table_insert(result, {app = app_name, version = ver, count = sum})
		end
	end 

	return cjson_encode(result)
end

local function statistics_from_db( start_date, end_date)
    local sql = string_format("select app, version, count(*) from (select distinct * from crash_report where time >= '%s' and time <= '%s') as static_query group by app, version", start_date, end_date)
    return select_from_db(sql)
end

function statistics(req, resp)
    if req.method == "GET" then
        if req.uri_args ~= nil then
			local red = connect_to_redis("127.0.0.1", 6379)
            local start_date = req.uri_args["start"]
            local end_date = req.uri_args["end"]
            --local result = statistics_from_db(start_date, end_date)
			local app = req.uri_args["app"]
			local version = req.uri_args["version"]
			local result = ""
			if app == nil then
				if version == nil then
					result =  statistics_all_from_db(red, start_date, end_date)
				end
			else
				result = statistics_single_from_db(red, start_date, end_date, app, version)
			end

            resp:write(result)
        end
    end
end

function crashlog(req, resp)
    local result = ""
    if req.method == "GET" then
        if req.uri_args ~= nil then
            local args = req.uri_args
            local where_table = {}
            local query_clause = {"app", "version", "lan", "device_id"}
            for _, v in ipairs(query_clause) do
                if args[v] ~= nil then
                    table_insert(where_table, string_format("%s = '%s'", v, args[v]))
                end
            end

            local where_sql = table_concat(where_table, " and ")
            local limit_clause = args["limit"] and string_format("limit %s", args["limit"]) or ""
            local offset_clause = args["offset"] and string_format("offset %s", args["offset"]) or ""
            local sql = string_format("select * from crash_report where %s %s %s", where_sql, limit_clause, offset_clause)
            logger:debug("Query String is: %s", sql)
            result = select_from_db(sql)
        end
    else
        logger:e("only support HTTP GET method")
    end

    resp:write(result)
end
