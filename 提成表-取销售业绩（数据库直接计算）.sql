declare @begindate datetime,@enddate datetime,@agentid int
set @begindate='2016-12-01 00:00:00'
set @enddate  ='2016-12-31 23:59:59'
set @agentid=15


--取销售表数据
select OrderNo
,cast(convert(varchar(10),x.AddTime,120)+' 00:00:00' as datetime) as dates   --取当天0点0分0秒
,x.AddTime,SAgentID,SalesName,ShiftID,o.ShiftName,SaleGroup,ODQuantity,ODBarcode
,GoodCateID,n.CateName,ODGoldPrice,GoodSaleFee,
goodtotalweight,GoodGoldWeight,ODRemGoldWeight,odsaleprice
,isnull(ODRealSalePrice,0)  ODRealSalePrice  --实售金额
,isnull(oldsaleprice,0)   oldsaleprice    --旧金金额

into #temp
from Order_s as x 
inner join OrderDetail_S as y on x.OrderNo=y.ODOrderNo
--旧金金额 是否抵扣看公司配置
left join (select  OOOrderNo,OOBarcode,SUM(OOSalePrice) OldSalePrice from OrderOld_S group by  OOOrderNo,OOBarcode) as z
on y.ODOrderNo=z.OOOrderNo and y.ODBarcode=z.OOBarcode
left join Good as m  on m.GoodBarcode=y.ODBarcode
left join Category as n on m.GoodCateID=n.CategoryID
left join Shift as o  on o.ID=x.ShiftID



where 1=1
--过滤分销商（权限过滤语句） 
and SAgentID =@agentid
and x.AddTime>=@begindate and x.AddTime<=@enddate


--取每个类别计算标准 
select x.ScheNo,x.cateid,MAX(CaleType) as caletype  
into #comcatecale
from ComCateCale as x inner join ComScheme as y on x.ScheNo=y.ScheNo
where AgentID=15
group by x.ScheNo,x.cateid



--给临时表增加   数据字段
alter table #temp   
add rates numeric(18,3)   --折扣率
,caletypes int            --取数类型
,Gcom numeric(18,4)   --公佣
,Pcom numeric(18,4)   --私佣 
,typess varchar(20)   --佣金方案名
,calrate numeric(18,3)  --计算标准
--select 

--CAST(
--case caletype 
--when 3 then round(GoodSaleFee,3)   --取销售工费
--when 2 then round((ODGoldPrice+GoodSaleFee)-(ODRealSalePrice)/(GoodGoldWeight-ODRemGoldWeight),3)             --取素金折扣  元/克
--when 1 then  round(ODRealSalePrice/ODSalePrice,3)              --取折扣 
--end
-- as numeric(18,3))
--,* 


--计算销售实际取值
update x set rates=
CAST(
case caletype 
when 3 then round(GoodSaleFee,3)   --取销售工费

--公式错了 未修正
when 2 then round((ODGoldPrice+GoodSaleFee)-(ODRealSalePrice)/(GoodGoldWeight-ODRemGoldWeight),3)             --取素金折扣  元/克
when 1 then round(ODRealSalePrice/ODSalePrice,3)              --取折扣 
end
 as numeric(18,3)),caletypes=y.caletype
from #temp as x 
left join #comcatecale as y on x.GoodCateID=y.cateid


--drop table #temp  drop table #comcatecale 


--根据取值直接匹配范围 计算出公佣  私佣
--select * from #temp
update x set 
 --不减旧金
 --Gcom=publicrate*(odrealsaleprice*getrate*0.01*0.01)
--,Pcom=PersonalRate*(odrealsaleprice*getrate*0.01*0.01)  --2个倍率是百分比所以要乘2次0.01
--如果是减旧金用下面的代码
 Gcom=publicrate*((odrealsaleprice-OldSalePrice)*getrate*0.01*0.01)
,Pcom=PersonalRate*((odrealsaleprice-OldSalePrice)*getrate*0.01*0.01)  --2个倍率是百分比所以要乘2次0.01
,typess=y.ComCateName
,calrate=GetRate
from #temp as x 
left join (select x.*,y.publicrate,y.PersonalRate from ComCateCale as x inner join ComScheme as y on x.ScheNo=y.ScheNo
where AgentID=15) as y
on x.GoodCateID=y.cateid  and x.rates>=CaleValueFrom and x.rates<=CaleValueTo

--分组求和  每天每个班组的公佣数据
select dates,SAgentID,ShiftID,ShiftName,SUM(gcom) gcom,SUM(pcom) pcom 
into #Pcom
from #temp as x 
group by dates,SAgentID,ShiftID,ShiftName



---按名字分组求和一次（怕员工记录重复，去除重复记录）
select @agentid agentid,AdminUserName,ShiftID,ShiftName,ScheData,MAX(isnull(salerlevel,'')) as salerlevel
,CAST(0.0000 as numeric(18,4)) as pcom   --私佣
,CAST(0.0000 as numeric(18,4)) as gcom   --公佣
into #adminuser
from BussScheDetail as x 
inner join AdminUser as y on x.CustomerID=y.AdminUserID
inner join Shift as z on x.ShiftID=z.ID
inner join BussSche  as m on x.ScheNo=m.ScheNo 
inner join AdminUserDetail as n on y.AdminUserID=n.AdminUserID
where 1=1
and m.AgentID=@agentid
and ScheData >=@begindate and ScheData<=@enddate
group by AdminUserName,ShiftID,ShiftName,ScheData
order by ScheData,ShiftID,AdminUserName

--#shiftcount  每天每班组各职位人数统计
select schedata,salerlevel,shiftname,shiftid,COUNT(*) as quan 
into #shiftcount
from #adminuser as x 
group by schedata,salerlevel,shiftname,shiftid

--select * from #adminuser


--更新私佣 销售明细表#temp 按销售员名，时间（当天0点0分0秒），班次id分组
--select *
update y set pcom=x.pcom
 from 
(select SalesName,dates,ShiftID,SUM(pcom) as pcom from #temp as x
group by SalesName,dates,ShiftID) as x
inner join  #adminuser as y on x.salesname=y.adminusername and x.dates=y.schedata and x.shiftid=y.shiftid

--select * from #adminuser




--取配置表计算公式
select IDENTITY(int,1,1) as res,x.ScheNo,ShiftID,salerlevel,CaleWay,CaleBase,salerlevelMultiple,CaleRank 
into #ComStaffCale
from ComStaffCale as x 
inner join ComScheme as y on x.ScheNo=y.ScheNo 
where AgentID=15
order by CaleRank

--将计算公式列转行   计算所有职位
  select
    res,salerlevel,CaleWay,CaleBase, 
    --a.name, 
    SUBSTRING(a.salerlevelMultiple,number,CHARINDEX(',',a.salerlevelMultiple+',',number)-number) as NAME ,CaleRank
    into #ComStaffCalePerson
from
    #ComStaffCale a,master..spt_values 
where
    number >=1 and number<=len(a.salerlevelMultiple)  
    and type='p' 
    and substring(','+a.salerlevelMultiple,number,1)=','




--循环计算公式
create table #tmp   --select * from #tmp
(
res int identity(1,1),
dates datetime,
shiftid int,
shiftname varchar(20),
gcom numeric(18,4),
pcom numeric(18,4),
salerlevel varchar(20),
caleway varchar(40),
levelcom numeric(18,4),
results  varchar(40),
results1 numeric(18,4)
)

declare @i int,@n int
set @i=1
while @i<=(select MAX(res) from #ComStaffCale)
begin               --1
  print '序号:'+cast(@i as varchar(20));
  set @n=(select calebase from #ComStaffCale where res=@i);
  
  --计算公式=1   合计公佣/计算人数
  if @n=1
      begin  --1.1
        truncate table #tmp
        insert into #tmp(dates,ShiftID,ShiftName,gcom,pcom,salerlevel,CaleWay,levelcom,results,results1)
        select dates,x.ShiftID,ShiftName,gcom,pcom,salerlevel,CaleWay
        ,cast(round(gcom/quans,4) as numeric(18,4)) as levelcom 
        ,REPLACE(CaleWay,'a',cast(cast(round(gcom/quans,4) as numeric(18,4)) as varchar(20))) as results
        ,CAST(0 as numeric(18,2)) as results1 
    
        --公佣合计 
        from #Pcom as x
        --取出当前循环对应的公式
        inner join (select * from #ComStaffCale where res=@i        --@i
                   )  as y on x.ShiftID=y.ShiftID
        --取出当班实际人数
        inner join (select schedata,ShiftID,SUM(quan) as quans from #shiftcount as aa 
                    where aa.salerlevel in(select NAME from #ComStaffCalePerson where res=@i   --@i
                    ) 
                    and aa.ShiftID in(select ShiftID from #ComStaffCale where res=@i     --@i
                    )
                    group by schedata,ShiftID
                    )  as z on z.ShiftID=x.ShiftID and z.ScheData=x.dates
        
        
        --循环动态语句
        --循环计算 当前职位 应得的佣金
        
        declare @ii int         --总天数循环
        declare @rs numeric(18,4) --执行语句输出结果  也就是每一笔记录公式计算出最终结果  临时变量
        set @ii=1
        declare @sql nvarchar(max)
        while @ii<=(select COUNT(*) from #tmp)       --循环#tmp表
          begin   --1.1.1
        --拼语句动态循环执行
        select @sql=
        ' select @a=' 
        +results from [#tmp] where res=@ii
        
        --print (@sql)
        exec sp_executesql @sql,N'@a numeric(18,4) output',@rs output
        --print @rs
        --更新#tmp表结果
        update x set  results1=@rs
        from #tmp as x 
        where x.res=@ii
        
        --循环值+1
        set @ii=@ii+1
          end    --1.1.1
        
        --循环完之后   根据结果 刷新明细记录
     
        --select * 
        update y set gcom=x.results1
        from #tmp as x inner join  #adminuser as y 
        on x.ShiftID=y.ShiftID and x.dates=y.ScheData and x.salerlevel=y.salerlevel
        
       -- select 0 as types,* from #tmp
        
       end   --1.1
       
       
       
       --其他用剩余佣金计算   剩余佣金/计算人数
  else
     begin    --1.2
        truncate table #tmp
        insert into #tmp(dates,ShiftID,ShiftName,gcom,pcom,salerlevel,CaleWay,levelcom,results,results1)
            select dates,x.ShiftID,x.ShiftName,gcom,pcom,salerlevel,CaleWay
        --取剩余佣金  如果剩余佣金小于0 则赋值为0 第一步 合计佣金公式里面不存在这个问题
        ,case when (gcom-realgcom)<0 then 0.0000 else   cast(round((gcom-realgcom)/quans,4) as numeric(18,4)) end as levelcom 
        ,REPLACE(CaleWay,'a',cast(cast(round(case when (gcom-realgcom)<0 then 0.0000 else   cast(round((gcom-realgcom)/quans,4) as numeric(18,4)) end,2) as numeric(18,4)) as varchar(20))) as results
        ,CAST(0 as numeric(18,4)) as results1 
                   
                    
                    --公佣合计 
                    from #Pcom as x
                    --取出当前循环对应的公式
                    inner join (select * from #ComStaffCale where res=@i    --@i
                   )  as y on x.ShiftID=y.ShiftID
                    inner join 
                    --计算当班人数（取实际上班人数）
                    (select schedata,ShiftID,SUM(quan) as quans from #shiftcount as aa 
                    where aa.salerlevel in(select NAME from #ComStaffCalePerson where res=@i   --@i   
                                           ) 
                    and aa.ShiftID in(select ShiftID from #ComStaffCale where res=@i          --@i 
                                     )
                    group by schedata,ShiftID
                    )  as z on z.ShiftID=x.ShiftID and z.ScheData=x.dates
                    inner join 
                    --取已分配佣金合计数据
                    (select ScheData,ShiftName,shiftid,sum(Gcom) as realgcom from #adminuser  as x 
                    where x.ShiftID in(select ShiftID from #ComStaffCale where res=@i         --@i 
                                     )
                                     group by ScheData,ShiftName,shiftid
                                     ) as m  on x.dates=m.ScheData and x.ShiftID=m.ShiftID 
                                     
       --循环动态语句部分
                                     
        declare @ii1 int         --总天数循环
        declare @rs1 numeric(18,4) --执行语句输出结果  也就是每一笔记录公式计算出最终结果  临时变量
        set @ii1=1
        declare @sql1 nvarchar(max)
        while @ii1<=(select COUNT(*) from #tmp)       --循环#tmp表
           begin    --1.2.1
        --拼语句动态循环执行
        select @sql1=
        ' select @a=' 
        +results from [#tmp] where res=@ii1
        
       
        exec sp_executesql @sql1,N'@a numeric(18,4) output',@rs1 output
    
        --更新#tmp表结果
        update x set  results1=@rs1
        from #tmp as x 
        where x.res=@ii1
        
        --print (@rs1)
        --循环值+1
        set @ii1=@ii1+1
           end    --1.2.1
        
        --循环完之后   根据结果 刷新明细记录
     
        --select * from #tmp1
        update y set gcom=x.results1
        from #tmp as x inner join  #adminuser as y 
        on x.ShiftID=y.ShiftID and x.dates=y.ScheData and x.salerlevel=y.salerlevel
         
          --select 1 as types,* from #tmp
       
     end  --1.2

--print '计算值:'+cast(@n as varchar(20))
--外循环值+1


set @i=@i+1
end    --1
--删除#tmp表


--插入有私佣  无排班的记录 （异常记录  排班表BussScheDetail无记录  销售orde_s表有记录）	

insert into #adminuser(agentid,AdminUserName,ShiftID,ShiftName,ScheData,salerlevel,gcom,pcom)
select y.sagentid,y.SalesName,y.shiftid,y.shiftname,y.dates,y.salerlevel
,0    --异常记录 不插入公佣  公佣已在前面分配完毕
,y.pcom   --私佣记录
from #adminuser as x 
full join 
(
select sagentid,SalesName,ShiftID,ShiftName,dates,SUM(gcom) as gcom,SUM(pcom) as pcom,z.salerlevel from #temp as y
left join (
           select m.AdminUserID,m.AdminUserName,n.salerlevel from AdminUser as m 
           left join AdminUserDetail as n 
           on m.AdminUserID=n.AdminUserID 
           where AgentID=@agentid
           )as z   on y.SalesName=z.AdminUserName
group by y.sagentid,SalesName,ShiftID,ShiftName,dates,salerlevel
) as y 
on x.ScheData=y.dates and x.AdminUserName=y.SalesName and x.ShiftID=y.ShiftID
where x.AdminUserName is null
order by dates



--select * from #temp      --销售明细数据  每笔公私佣明细
--select * from #ComCateCale     --类别计算规则
--select * from #Pcom            --公佣合计
--select * from #adminuser       --员工排班明细+公佣明细
--select * from #shiftcount      --员工排班统计（按职位）
--select * from #ComStaffCale    --计算公式
--select * from #ComStaffCalePerson   --公式员工  列转行





-------------------------------------------------------------
-------------------------------------------------------------
-------------------------------------------------------------
--删除佣金表数据StaffCom 表里面缺和主表的管理 agentid
--select * 
----delete x 
--from StaffCom as x 
--where 1=1 
----缺分销商  数据还未替换 
--and saledate>='2016-12-01 00:00:00' and saledate<='2016-12-31 23:59:59'



--插入佣金表数据StaffCom   select * from StaffCom
--insert into StaffCom(SalerID,SaleDate,GetMoney,GetType,ShiftID)
select --x.agentid,
AdminUserID as userid,ScheData as SaleDate,pcom GetMoney,2 GetType,ShiftID from #adminuser as x
left join AdminUser as y on x.AdminUserName=y.AdminUserName
union all 
select --x.agentid,
AdminUserID,ScheData,gcom,1,ShiftID from #adminuser as x
left join AdminUser as y on x.AdminUserName=y.AdminUserName


 
 
 
------清空临时表
--    drop table #tmp
--    drop table #temp      --销售明细数据  每笔公私佣明细
--    drop table #ComCateCale     --类别计算规则
--    drop table #Pcom            --公佣合计
--    drop table #adminuser       --员工排班明细+公佣明细
--	drop table #shiftcount      --员工排班统计（按职位）
--	drop table #ComStaffCale    --计算公式
--	drop table #ComStaffCalePerson   --公式员工  列转行
	
	
 
 
 

--佣金计算明细数据
select OrderNo 销售单号,dates 日期,ShiftName 当班班次,SaleGroup 当班分组,ODQuantity 数量,ODBarcode 条码,CateName 类别
,rates as [标准数据(工费|折扣)],typess 计算标准,right(cast(cast(round(calrate,2) as numeric(18,2)) as varchar(20)),20)+'%' 提点比率
,ODRealSalePrice 实售价
,oldsaleprice 旧金金额
,gcom 公佣,pcom 私佣
 from #temp as x 
where dates='2016-12-01'
order by ShiftID,orderno


--select SUM(pcom),SUM(gcom) from #adminuser as x 
--select * from #adminuser as xx
--
--select * from #adminuser
--order by schedata,shiftid,salerlevel


--select * 
--from #adminuser as x 
--where pcom<>0 and gcom=0


--select * from #temp as x
--inner join 
--(
--select * 
--from #adminuser as x 
--where pcom<>0 and gcom=0
--) as y
--on x.dates=y.ScheData and x.SalesName=y.AdminUserName and x.ShiftName=y.ShiftName
--order by dates,salesname
