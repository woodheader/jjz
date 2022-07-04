#!/bin/bash

# 进京证状态查询接口
jjz_state_api="https://xxxx/stateList"
# 进京证申请接口
jjz_apply_api="https://xxxx/insertApplyRecord"
# 企业微信机器人API
wxbot_api="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=xxxx"
# y-m-d h:i:s 格式当前日期
dt=`date "+%Y-%m-%d %H:%M:%S"`
# y-m-d 格式当前日期
dt_ymd=`date "+%Y-%m-%d"`
# 明天日期
dt_next_day=''
# 毫秒格式当前日期
cur_timestamp=""
# 需要判断系统类型，mac不支持直接获取毫秒
if [ "$(uname)" = "Darwin" ]
then
	cur_timestamp=$((`gdate -d "$dt" +%s`*1000+10#`gdate "+%N"`/1000000))
	dt_next_day=`gdate -d next-day +%Y-%m-%d`
else
	cur_timestamp=$((`date -d "$dt" +%s`*1000+10#`date "+%N"`/1000000))
	dt_next_day=`date -d next-day +%Y-%m-%d`
fi;

# 状态查询接口，进京证头部信息，对应：authorization
auth=''
# 状态查询接口，进京证头部信息，对应：RemoteIp
ip=''
# 状态查询接口，进京证头部信息，对应：source
source=''
# 状态查询接口，这里需要填写你自己的身份证号
idcard=''
# 申请接口，要提交的数据，自己先抓包，然后把数据放到这里 - 这里注意一点：json里的一个参数 jjrq 的值，需要替换成：$dt_next_day，用于还剩 1 天的时候，申请新的进京证
apply_data=''


# 检查进京证是否过期
state_result=$(curl -s -XPOST $jjz_state_api -H 'content-type:application/json;charset=utf-8;' -H 'Time: '$dt'' -H 'Size: 710' -H 'RemoteIp: '$ip'' -H 'User-Agent: okhttp-okgo/jeasonlzy' -H 'source: '$source'' -H 'authorization: '$auth'' -H 'Content-Length: 59' -H 'Host: jjz.jtgl.beijing.gov.cn' -H 'Connection: Keep-Alive' -H 'Accept-Encoding: gzip' -d '{"sfzmhm":"'$idcard'","timestamp":"'$cur_timestamp'"}')

sleep 3s
echo '查询响应内容：'$state_result

# 解析返回状态
# 检查 code ，401表示auth过期，200表示正常
msg=$(echo $state_result| jq .msg)
msg=`echo ${msg//\"/}`
code=$(echo $state_result| jq .code)

echo '查询响应状态码：'$code
echo '查询响应消息：'$msg


# 异常状态报警
if [ $code != "200" ]
then
	echo '请求官方接口异常,状态码不等于200'
	# 通知企业微信
	curl -s -XPOST $wxbot_api -H 'Content-Type:application/json' -d "{\"msgtype\":\"markdown\",\"markdown\":{\"content\":\">**告警**\n>\n>状态码：$code\n>内容：$msg\n>时间：$dt\"}}";
	exit
fi

# 200 情况下，检查办证状态
expire_day=$(echo $state_result| jq .data.bzclxx[0].bzxx[0].sxsyts)
expire_day_cn=$expire_day' 天'
current_state=$(echo $state_result| jq .data.bzclxx[0].bzxx[0].blztmc)
current_state=`echo ${current_state//\"/}`
echo '查询办证状态：'$current_state
curl -s -XPOST $wxbot_api -H 'Content-Type:application/json' -d "{\"msgtype\":\"markdown\",\"markdown\":{\"content\":\">**查询办证状态**\n>\n>状态码：$code\n>内容：$current_state\n>剩余天数：$expire_day_cn\n>时间：$dt\"}}";
if [ $current_state = '审核通过(生效中)' ]
then
  echo '当前进京证正在生效中，不用再次申请'
  echo '当前进京证剩余天数：'$expire_day'天！'
  # 当剩余天数大于1天时，不需要申请；小于等于1天时，自动申请
  if [ $expire_day -gt 1 ]
  then
  	exit
  fi;
fi

# 申请进京证
apply_result=$(curl -s -XPOST $jjz_apply_api -H 'content-type:application/json;charset=utf-8;' -H 'Time: '$dt'' -H 'Size: 710' -H 'RemoteIp: '$ip'' -H 'User-Agent: okhttp-okgo/jeasonlzy' -H 'source: '$source'' -H 'authorization: '$auth'' -H 'Content-Length: 339' -H 'Host: jjz.jtgl.beijing.gov.cn' -H 'Connection: Keep-Alive' -H 'Accept-Encoding: gzip' -d $apply_data)

sleep 3s;
echo '办理结果：'$apply_result

# 解析返回状态
msg=$(echo $apply_result| jq .msg)
msg=`echo ${msg//\"/}`
code=$(echo $apply_result| jq .code)

echo '办理响应状态码：'$code
echo '办理响应消息：'$msg

# 办理结果发送企业微信
curl -s -XPOST $wxbot_api -H 'Content-Type:application/json' -d "{\"msgtype\":\"markdown\",\"markdown\":{\"content\":\">**办理结果**\n>\n>状态码：$code\n>内容：$msg\n>时间：$dt\"}}";