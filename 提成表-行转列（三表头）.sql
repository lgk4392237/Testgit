declare @begindate datetime,@enddate datetime,@agentid int
set @begindate='2016-12-01 00:00:00'
set @enddate='2016-12-31 23:59:59'
set @agentid=15     --AgentCom 和 StaffCom 未设置关联


--StaffCom员工佣金表 搜索全部数据 
--saledate存储的时间为每天0点0分0秒
select y.AdminUserName,x.SalerID,x.SaleDate,x.ShiftID,m.ShiftName,z.salerlevel,z.SalerGroup,GetMoney
,case x.GetType when 1 then '公佣' when 2 then '私佣' end as gettype
,isnull(z.rank,1) as rank
into #staffcom
from StaffCom as x 
left join AdminUser as y on x.SalerID=y.AdminUserID
left join AdminUserDetail as z  on y.AdminUserID=z.AdminUserID
left join Shift  as m on m.ID=x.ShiftID
where x.SaleDate>=@begindate and x.SaleDate<=@enddate 

--select * from #staffcom as x     --drop table #staffcom

--插入行总合计   按日期,班次名（班次id）,佣金类型（公佣,私佣）
insert into #staffcom(AdminUserName,SalerID,SaleDate,ShiftID,ShiftName,salerlevel,SalerGroup,GetMoney,gettype,rank)
select '',0,SaleDate,ShiftID,ShiftName,'','总合计',SUM(GetMoney),gettype,999999 as rank 
from #staffcom as x 
group by SaleDate,ShiftID,ShiftName,gettype


--插入列总合计   
insert into #staffcom(AdminUserName,SalerID,SaleDate,ShiftID,ShiftName,salerlevel,SalerGroup,GetMoney,gettype,rank)
select AdminUserName,0,@enddate,0,'总合计',salerlevel,SalerGroup,SUM(GetMoney),'',999998
from #staffcom as x 

group by AdminUserName,salerlevel,SalerGroup


DECLARE @sql VARCHAR(max)

SET @sql = 'select adminusername,salerlevel,salergroup '

SELECT @sql = @sql + ',        sum(case cast(saledate as varchar(20))+shiftname+gettype when ''' 
+ cast(SaleDate as varchar(20))+ShiftName+gettype + ''' then getmoney else 0 end) as ''' 
+ (case ShiftName when '总合计' 
then right(left(cast(CONVERT(varchar(12) , SaleDate, 120 )  as varchar(20)),7),2)+'月|'+ShiftName
else (right(left(cast(CONVERT(varchar(12) , SaleDate, 120 )  as varchar(20)),10),5)+'|'+ShiftName+'|'+gettype) end) + ''''
FROM   (SELECT TOP 10000 SaleDate,ShiftName,gettype
        FROM   #staffcom
        GROUP  BY SaleDate,ShiftName,gettype
        ORDER  BY SaleDate,Max(ShiftID),gettype
        ) AS a

SET @sql = @sql + ' from #staffcom  group by adminusername,salerlevel,salergroup 
       order by isnull(salergroup,''总合计''),min(rank),salerlevel,adminusername
    '
--print @sql
EXEC(@sql)


--删除临时表
--drop table #staffcom



