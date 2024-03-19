use taobao;

#查询数据集记录数
select count(*)
from userbehavior u;

#查询数据集中的重复记录
select 用户id,商品id,商品类目id,行为类型,行为时间
from userbehavior u 
group by 用户id,商品id,商品类目id,行为类型,行为时间
having count(*)>1;

#去除重复数据，将去重后的1000000条数据插入新建立的表格
create table userbehavior2 as(
select *
from userbehavior 
group by 用户id,商品id,商品类目id,行为类型,行为时间
having count(*)=1
limit 1000000
);

#查看数据中是否有缺失值
select 
count(用户id),count(商品id),count(商品类目id),count(行为类型),count(行为时间)
from userbehavior2;

#新增日期、时间、小时列
alter table userbehavior2 add date_time varchar(10);
update userbehavior2 
set date_time= date(from_unixtime(行为时间));
alter table userbehavior2 add v_time varchar(10);
update userbehavior2 
set v_time=time(from_unixtime(行为时间));
alter table userbehavior2 rename column date_time to v_date;
alter table userbehavior2  add v_hour varchar(4);
update userbehavior2 
set v_hour=substr(v_time,1,2);

#去除异常数据
select min(v_date),max(v_date)
from userbehavior2 ;
delete from userbehavior2 where v_date<'2017-11-25' or v_date>'2017-12-03';



#用户行为数据分析
select 
count(distinct 用户id) as 用户数量,
count(distinct 商品id) as 商品数量,
count(distinct 商品类目id) as 商品种类数量,
count(distinct 行为类型) as 行为类型数量,
count(distinct v_date) as 天数,
min(v_date) as 最早日期,
max(v_date) as 最晚日期
from userbehavior2 ;

#查询总体独立用户数、pv、人均浏览次数=pv/用户数量、成交量
select 
count(distinct 用户id) as 用户数量,
sum(if(行为类型='pv',1,0)) as 点击数,
sum(if(行为类型='pv',1,0))/count(distinct 用户id) as 人均点击数,
sum(if(行为类型='buy',1,0)) as 成交量
from userbehavior2 ;

#查询独立用户数、每日pv、人均浏览次数=pv/用户数量、成交量
select 
v_date as 日期,
count(distinct 用户id) as 用户数量,
sum(if(行为类型='pv',1,0)) as 点击数,
sum(if(行为类型='pv',1,0))/count(distinct 用户id) as 人均点击数,
sum(if(行为类型='buy',1,0)) as 成交量
from userbehavior2 
group by 日期
order by 日期;

#查询每时间段独立用户数、pv、人均浏览次数=pv/用户数量、成交量
select 
v_hour as 小时,
count(distinct 用户id) as 用户数量,
sum(if(行为类型='pv',1,0)) as 点击数,
sum(if(行为类型='pv',1,0))/count(distinct 用户id) as 人均点击数,
sum(if(行为类型='buy',1,0)) as 成交量
from userbehavior2 
group by 小时
order by 小时;

#一天之内的点击成交转化率
select t2.小时,t2.成交量/t2.点击数 as 点击成交转化率
from(
select 
v_hour as 小时,
count(distinct 用户id) as 用户数量,
sum(if(行为类型='pv',1,0)) as 点击数,
sum(if(行为类型='pv',1,0))/count(distinct 用户id) as 人均点击数,
sum(if(行为类型='buy',1,0)) as 成交量
from userbehavior2 
group by 小时
order by 小时
) t2;

#创建用户行为视图
create view UserBehavior3 as(
select 
用户id,
count(行为类型) as 行为类型数,
sum(if(行为类型='pv',1,0)) as 点击数,
sum(if(行为类型='cart',1,0)) as 加购数,
sum(if(行为类型='fav',1,0)) as 收藏量,
sum(if(行为类型='pv',1,0)) as 成交量
from userbehavior2 
group by 用户id
);


#用户留存分析 指标pv
select 
base.v_date,
keep.day,
base.use_count,
keep.count,
keep.count/base.use_count
from (
select v_date,count(distinct 用户id) as use_count from userbehavior2 where 行为类型='pv' group by v_date) base
left join(
select 
begin_day,
day,
count(*) as count
from
(select 
a.用户id,
a.v_date as begin_day,
b.v_date,
datediff(b.v_date,a.v_date) as day
from
(select 用户id,v_date 
from userbehavior2 
where 行为类型='pv' 
group by 用户id,v_date) a 
left join 
(select 用户id,v_date 
from userbehavior2 
where 行为类型='pv' 
group by 用户id,v_date) b
on a.用户id=b.用户id
where a.v_date<b.v_date
group by 
a.用户id,
a.v_date,
b.v_date)aa
group by begin_day,day) keep
on keep.begin_day=base.v_date;


#漏斗模型
#计算总计点击量、加购量、收藏量和成交量
select 
count(distinct 用户id) as uv,
sum(if (行为类型='pv', 1 , 0)) as 点击量,
sum(if (行为类型='cart',  1,  0)) as 加购量,
sum(if (行为类型='fav', 1 , 0)) as 收藏量,
sum(if (行为类型='buy',  1, 0)) as 成交量
from userbehavior2 ;

#计算每种行为类型的独立用户数和行为量
select 
行为类型,
count(distinct 用户id) as 独立用户数,
sum(if(行为类型='pv',1,0)) as '点击',
sum(if(行为类型='fav',1,0)) as '收藏',
sum(if(行为类型='cart',1,0)) as '加购',
sum(if(行为类型='buy',1,0)) as '成交'
from userbehavior2 
group by 行为类型;

#商品维度分析 6589
select 
count(distinct 用户id) as 购买人数
from userbehavior2
where 行为类型='buy';

#查询各商品的行为类型总数作为视图
create view product as(
select 
商品id,
sum(if(行为类型='pv',1,0)) as 点击数,
sum(if(行为类型='fav',1,0)) as 收藏数,
sum(if(行为类型='cart',1,0)) as 加购数,
sum(if(行为类型='buy',1,0)) as 成交量
from userbehavior2 
group by 商品id
order by 点击数 desc
);

#计算每个行为类型前10的商品id
select 
商品id,
count(*) as num
from userbehavior2 
where 行为类型='pv'
group by 商品id
order by num desc 
limit 10;
select 
商品id,
count(*) as num
from userbehavior2 
where 行为类型='buy'
group by 商品id
order by num desc 
limit 10;
select 
商品id,
count(*) as num
from userbehavior2 
where 行为类型='cart'
group by 商品id
order by num desc 
limit 10;
select 
商品id,
count(*) as num
from userbehavior2 
where 行为类型='fav'
group by 商品id
order by num desc 
limit 10;

#商品类目
#求渗透率 买过此类商品的用户又买了其他商品的数量
select 
a1.商品类目id as 商品类目id,
count(distinct a2.商品类目id) as 渗透率
from(
select 用户id,商品类目id
from userbehavior2 
where 行为类型='buy'
group by 用户id,商品类目id) a1
left join 
(
select 用户id,商品类目id
from userbehavior2 
where 行为类型='buy'
group by 用户id,商品类目id
) a2
on a1.用户id=a2.用户id
group by 商品类目id
order by 渗透率 desc;

#用户价值分析 RFM模型 
#R为最近的消费时间
#F为时间段内的消费次数
select 
用户id,
min(datediff('2017-12-03',from_unixtime(行为时间)))  as 最近消费时间R值
from userbehavior2 
where 行为类型='buy'
group by 用户id;

#查询用户消费次数
select 
用户id,
count(*) as 消费次数F值
from userbehavior2 
where 行为类型='buy'
group by 用户id;

#创建RFM消费视图
create view RFM as(
select 
r.用户id,
r.最近消费时间间隔R值,
f.消费次数F值
from (
select 
用户id,
min(datediff('2017-12-03',from_unixtime(行为时间))) as 最近消费时间间隔R值
from userbehavior2 
where 行为类型='buy'
group by 用户id
) r
left join 
(
select 
用户id,
count(*) as 消费次数F值
from userbehavior2 
where 行为类型='buy'
group by 用户id
) f 
on r.用户id=f.用户id
);
select 
max(最近消费时间间隔R值),
max(消费次数F值)
from rfm;

#统计各个时间间隔用户数
select 
最近消费时间间隔R值,
count(用户id)
from rfm 
group by 最近消费时间间隔R值
order by 最近消费时间间隔R值
#统计各购买次数用户数
select 
消费次数F值,
count(用户id)
from rfm 
group by 消费次数F值
order by 消费次数F值;

#创建打分规则 基于视图再次创建视图
drop view rfm_value 
create view rfm_value as(
select *,
(case when 最近消费时间间隔R值<=1 then 5  
      when 最近消费时间间隔R值 =2 then 4
      when 最近消费时间间隔R值 between 2 and 5 then 3
      when 最近消费时间间隔R值 between 6 and 7 then 2
      when 最近消费时间间隔R值 >=8 then 1 end
      ) as R_value,
 (case when 消费次数F值 between 32 and 67 then 5 
 when 消费次数F值 between 17 and 31 then 4
 when 消费次数F值 between 8 and 16 then 3
 when 消费次数F值 between 4 and 7 then 2
 when 消费次数F值 between 1 and 3 then 1 end
 ) as F_value
from rfm);

#根据R、F值划分用户
drop view user_class
create view user_class as(
select *,
(case when R值高低='高' and F值高低='高' then 1
when R值高低='高' and F值高低='低' then 2
when R值高低='低' and F值高低='高' then 3
when R值高低='低' and F值高低='低' then 4 end) as 用户分类
from(
select 
用户id,
if(R_value>=(select avg(R_value) from rfm_value ),'高','低') as R值高低,
if(F_value>=(select avg(F_value) from rfm_value ),'高','低') as F值高低
from rfm_value 
) a1);

#统计各用户种类
select 用户分类,
count(*) as 用户数量
from user_class 
group by 用户分类
order by 用户分类 desc;





