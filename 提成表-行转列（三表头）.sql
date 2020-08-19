declare @begindate datetime,@enddate datetime,@agentid int
set @begindate='2016-12-01 00:00:00'
set @enddate='2016-12-31 23:59:59'
set @agentid=15     --AgentCom �� StaffCom δ���ù���


--StaffComԱ��Ӷ��� ����ȫ������ 
--saledate�洢��ʱ��Ϊÿ��0��0��0��
select y.AdminUserName,x.SalerID,x.SaleDate,x.ShiftID,m.ShiftName,z.salerlevel,z.SalerGroup,GetMoney
,case x.GetType when 1 then '��Ӷ' when 2 then '˽Ӷ' end as gettype
,isnull(z.rank,1) as rank
into #staffcom
from StaffCom as x 
left join AdminUser as y on x.SalerID=y.AdminUserID
left join AdminUserDetail as z  on y.AdminUserID=z.AdminUserID
left join Shift  as m on m.ID=x.ShiftID
where x.SaleDate>=@begindate and x.SaleDate<=@enddate 

--select * from #staffcom as x     --drop table #staffcom

--�������ܺϼ�   ������,����������id��,Ӷ�����ͣ���Ӷ,˽Ӷ��
insert into #staffcom(AdminUserName,SalerID,SaleDate,ShiftID,ShiftName,salerlevel,SalerGroup,GetMoney,gettype,rank)
select '',0,SaleDate,ShiftID,ShiftName,'','�ܺϼ�',SUM(GetMoney),gettype,999999 as rank 
from #staffcom as x 
group by SaleDate,ShiftID,ShiftName,gettype


--�������ܺϼ�   
insert into #staffcom(AdminUserName,SalerID,SaleDate,ShiftID,ShiftName,salerlevel,SalerGroup,GetMoney,gettype,rank)
select AdminUserName,0,@enddate,0,'�ܺϼ�',salerlevel,SalerGroup,SUM(GetMoney),'',999998
from #staffcom as x 

group by AdminUserName,salerlevel,SalerGroup


DECLARE @sql VARCHAR(max)

SET @sql = 'select adminusername,salerlevel,salergroup '

SELECT @sql = @sql + ',        sum(case cast(saledate as varchar(20))+shiftname+gettype when ''' 
+ cast(SaleDate as varchar(20))+ShiftName+gettype + ''' then getmoney else 0 end) as ''' 
+ (case ShiftName when '�ܺϼ�' 
then right(left(cast(CONVERT(varchar(12) , SaleDate, 120 )  as varchar(20)),7),2)+'��|'+ShiftName
else (right(left(cast(CONVERT(varchar(12) , SaleDate, 120 )  as varchar(20)),10),5)+'|'+ShiftName+'|'+gettype) end) + ''''
FROM   (SELECT TOP 10000 SaleDate,ShiftName,gettype
        FROM   #staffcom
        GROUP  BY SaleDate,ShiftName,gettype
        ORDER  BY SaleDate,Max(ShiftID),gettype
        ) AS a

SET @sql = @sql + ' from #staffcom  group by adminusername,salerlevel,salergroup 
       order by isnull(salergroup,''�ܺϼ�''),min(rank),salerlevel,adminusername
    '
--print @sql
EXEC(@sql)


--ɾ����ʱ��
--drop table #staffcom



