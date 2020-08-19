declare @begindate datetime,@enddate datetime,@agentid int
set @begindate='2016-12-01 00:00:00'
set @enddate  ='2016-12-31 23:59:59'
set @agentid=15


--ȡ���۱�����
select OrderNo
,cast(convert(varchar(10),x.AddTime,120)+' 00:00:00' as datetime) as dates   --ȡ����0��0��0��
,x.AddTime,SAgentID,SalesName,ShiftID,o.ShiftName,SaleGroup,ODQuantity,ODBarcode
,GoodCateID,n.CateName,ODGoldPrice,GoodSaleFee,
goodtotalweight,GoodGoldWeight,ODRemGoldWeight,odsaleprice
,isnull(ODRealSalePrice,0)  ODRealSalePrice  --ʵ�۽��
,isnull(oldsaleprice,0)   oldsaleprice    --�ɽ���

into #temp
from Order_s as x 
inner join OrderDetail_S as y on x.OrderNo=y.ODOrderNo
--�ɽ��� �Ƿ�ֿۿ���˾����
left join (select  OOOrderNo,OOBarcode,SUM(OOSalePrice) OldSalePrice from OrderOld_S group by  OOOrderNo,OOBarcode) as z
on y.ODOrderNo=z.OOOrderNo and y.ODBarcode=z.OOBarcode
left join Good as m  on m.GoodBarcode=y.ODBarcode
left join Category as n on m.GoodCateID=n.CategoryID
left join Shift as o  on o.ID=x.ShiftID



where 1=1
--���˷����̣�Ȩ�޹�����䣩 
and SAgentID =@agentid
and x.AddTime>=@begindate and x.AddTime<=@enddate


--ȡÿ���������׼ 
select x.ScheNo,x.cateid,MAX(CaleType) as caletype  
into #comcatecale
from ComCateCale as x inner join ComScheme as y on x.ScheNo=y.ScheNo
where AgentID=15
group by x.ScheNo,x.cateid



--����ʱ������   �����ֶ�
alter table #temp   
add rates numeric(18,3)   --�ۿ���
,caletypes int            --ȡ������
,Gcom numeric(18,4)   --��Ӷ
,Pcom numeric(18,4)   --˽Ӷ 
,typess varchar(20)   --Ӷ�𷽰���
,calrate numeric(18,3)  --�����׼
--select 

--CAST(
--case caletype 
--when 3 then round(GoodSaleFee,3)   --ȡ���۹���
--when 2 then round((ODGoldPrice+GoodSaleFee)-(ODRealSalePrice)/(GoodGoldWeight-ODRemGoldWeight),3)             --ȡ�ؽ��ۿ�  Ԫ/��
--when 1 then  round(ODRealSalePrice/ODSalePrice,3)              --ȡ�ۿ� 
--end
-- as numeric(18,3))
--,* 


--��������ʵ��ȡֵ
update x set rates=
CAST(
case caletype 
when 3 then round(GoodSaleFee,3)   --ȡ���۹���

--��ʽ���� δ����
when 2 then round((ODGoldPrice+GoodSaleFee)-(ODRealSalePrice)/(GoodGoldWeight-ODRemGoldWeight),3)             --ȡ�ؽ��ۿ�  Ԫ/��
when 1 then round(ODRealSalePrice/ODSalePrice,3)              --ȡ�ۿ� 
end
 as numeric(18,3)),caletypes=y.caletype
from #temp as x 
left join #comcatecale as y on x.GoodCateID=y.cateid


--drop table #temp  drop table #comcatecale 


--����ȡֱֵ��ƥ�䷶Χ �������Ӷ  ˽Ӷ
--select * from #temp
update x set 
 --�����ɽ�
 --Gcom=publicrate*(odrealsaleprice*getrate*0.01*0.01)
--,Pcom=PersonalRate*(odrealsaleprice*getrate*0.01*0.01)  --2�������ǰٷֱ�����Ҫ��2��0.01
--����Ǽ��ɽ�������Ĵ���
 Gcom=publicrate*((odrealsaleprice-OldSalePrice)*getrate*0.01*0.01)
,Pcom=PersonalRate*((odrealsaleprice-OldSalePrice)*getrate*0.01*0.01)  --2�������ǰٷֱ�����Ҫ��2��0.01
,typess=y.ComCateName
,calrate=GetRate
from #temp as x 
left join (select x.*,y.publicrate,y.PersonalRate from ComCateCale as x inner join ComScheme as y on x.ScheNo=y.ScheNo
where AgentID=15) as y
on x.GoodCateID=y.cateid  and x.rates>=CaleValueFrom and x.rates<=CaleValueTo

--�������  ÿ��ÿ������Ĺ�Ӷ����
select dates,SAgentID,ShiftID,ShiftName,SUM(gcom) gcom,SUM(pcom) pcom 
into #Pcom
from #temp as x 
group by dates,SAgentID,ShiftID,ShiftName



---�����ַ������һ�Σ���Ա����¼�ظ���ȥ���ظ���¼��
select @agentid agentid,AdminUserName,ShiftID,ShiftName,ScheData,MAX(isnull(salerlevel,'')) as salerlevel
,CAST(0.0000 as numeric(18,4)) as pcom   --˽Ӷ
,CAST(0.0000 as numeric(18,4)) as gcom   --��Ӷ
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

--#shiftcount  ÿ��ÿ�����ְλ����ͳ��
select schedata,salerlevel,shiftname,shiftid,COUNT(*) as quan 
into #shiftcount
from #adminuser as x 
group by schedata,salerlevel,shiftname,shiftid

--select * from #adminuser


--����˽Ӷ ������ϸ��#temp ������Ա����ʱ�䣨����0��0��0�룩�����id����
--select *
update y set pcom=x.pcom
 from 
(select SalesName,dates,ShiftID,SUM(pcom) as pcom from #temp as x
group by SalesName,dates,ShiftID) as x
inner join  #adminuser as y on x.salesname=y.adminusername and x.dates=y.schedata and x.shiftid=y.shiftid

--select * from #adminuser




--ȡ���ñ���㹫ʽ
select IDENTITY(int,1,1) as res,x.ScheNo,ShiftID,salerlevel,CaleWay,CaleBase,salerlevelMultiple,CaleRank 
into #ComStaffCale
from ComStaffCale as x 
inner join ComScheme as y on x.ScheNo=y.ScheNo 
where AgentID=15
order by CaleRank

--�����㹫ʽ��ת��   ��������ְλ
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




--ѭ�����㹫ʽ
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
  print '���:'+cast(@i as varchar(20));
  set @n=(select calebase from #ComStaffCale where res=@i);
  
  --���㹫ʽ=1   �ϼƹ�Ӷ/��������
  if @n=1
      begin  --1.1
        truncate table #tmp
        insert into #tmp(dates,ShiftID,ShiftName,gcom,pcom,salerlevel,CaleWay,levelcom,results,results1)
        select dates,x.ShiftID,ShiftName,gcom,pcom,salerlevel,CaleWay
        ,cast(round(gcom/quans,4) as numeric(18,4)) as levelcom 
        ,REPLACE(CaleWay,'a',cast(cast(round(gcom/quans,4) as numeric(18,4)) as varchar(20))) as results
        ,CAST(0 as numeric(18,2)) as results1 
    
        --��Ӷ�ϼ� 
        from #Pcom as x
        --ȡ����ǰѭ����Ӧ�Ĺ�ʽ
        inner join (select * from #ComStaffCale where res=@i        --@i
                   )  as y on x.ShiftID=y.ShiftID
        --ȡ������ʵ������
        inner join (select schedata,ShiftID,SUM(quan) as quans from #shiftcount as aa 
                    where aa.salerlevel in(select NAME from #ComStaffCalePerson where res=@i   --@i
                    ) 
                    and aa.ShiftID in(select ShiftID from #ComStaffCale where res=@i     --@i
                    )
                    group by schedata,ShiftID
                    )  as z on z.ShiftID=x.ShiftID and z.ScheData=x.dates
        
        
        --ѭ����̬���
        --ѭ������ ��ǰְλ Ӧ�õ�Ӷ��
        
        declare @ii int         --������ѭ��
        declare @rs numeric(18,4) --ִ�����������  Ҳ����ÿһ�ʼ�¼��ʽ��������ս��  ��ʱ����
        set @ii=1
        declare @sql nvarchar(max)
        while @ii<=(select COUNT(*) from #tmp)       --ѭ��#tmp��
          begin   --1.1.1
        --ƴ��䶯̬ѭ��ִ��
        select @sql=
        ' select @a=' 
        +results from [#tmp] where res=@ii
        
        --print (@sql)
        exec sp_executesql @sql,N'@a numeric(18,4) output',@rs output
        --print @rs
        --����#tmp����
        update x set  results1=@rs
        from #tmp as x 
        where x.res=@ii
        
        --ѭ��ֵ+1
        set @ii=@ii+1
          end    --1.1.1
        
        --ѭ����֮��   ���ݽ�� ˢ����ϸ��¼
     
        --select * 
        update y set gcom=x.results1
        from #tmp as x inner join  #adminuser as y 
        on x.ShiftID=y.ShiftID and x.dates=y.ScheData and x.salerlevel=y.salerlevel
        
       -- select 0 as types,* from #tmp
        
       end   --1.1
       
       
       
       --������ʣ��Ӷ�����   ʣ��Ӷ��/��������
  else
     begin    --1.2
        truncate table #tmp
        insert into #tmp(dates,ShiftID,ShiftName,gcom,pcom,salerlevel,CaleWay,levelcom,results,results1)
            select dates,x.ShiftID,x.ShiftName,gcom,pcom,salerlevel,CaleWay
        --ȡʣ��Ӷ��  ���ʣ��Ӷ��С��0 ��ֵΪ0 ��һ�� �ϼ�Ӷ��ʽ���治�����������
        ,case when (gcom-realgcom)<0 then 0.0000 else   cast(round((gcom-realgcom)/quans,4) as numeric(18,4)) end as levelcom 
        ,REPLACE(CaleWay,'a',cast(cast(round(case when (gcom-realgcom)<0 then 0.0000 else   cast(round((gcom-realgcom)/quans,4) as numeric(18,4)) end,2) as numeric(18,4)) as varchar(20))) as results
        ,CAST(0 as numeric(18,4)) as results1 
                   
                    
                    --��Ӷ�ϼ� 
                    from #Pcom as x
                    --ȡ����ǰѭ����Ӧ�Ĺ�ʽ
                    inner join (select * from #ComStaffCale where res=@i    --@i
                   )  as y on x.ShiftID=y.ShiftID
                    inner join 
                    --���㵱��������ȡʵ���ϰ�������
                    (select schedata,ShiftID,SUM(quan) as quans from #shiftcount as aa 
                    where aa.salerlevel in(select NAME from #ComStaffCalePerson where res=@i   --@i   
                                           ) 
                    and aa.ShiftID in(select ShiftID from #ComStaffCale where res=@i          --@i 
                                     )
                    group by schedata,ShiftID
                    )  as z on z.ShiftID=x.ShiftID and z.ScheData=x.dates
                    inner join 
                    --ȡ�ѷ���Ӷ��ϼ�����
                    (select ScheData,ShiftName,shiftid,sum(Gcom) as realgcom from #adminuser  as x 
                    where x.ShiftID in(select ShiftID from #ComStaffCale where res=@i         --@i 
                                     )
                                     group by ScheData,ShiftName,shiftid
                                     ) as m  on x.dates=m.ScheData and x.ShiftID=m.ShiftID 
                                     
       --ѭ����̬��䲿��
                                     
        declare @ii1 int         --������ѭ��
        declare @rs1 numeric(18,4) --ִ�����������  Ҳ����ÿһ�ʼ�¼��ʽ��������ս��  ��ʱ����
        set @ii1=1
        declare @sql1 nvarchar(max)
        while @ii1<=(select COUNT(*) from #tmp)       --ѭ��#tmp��
           begin    --1.2.1
        --ƴ��䶯̬ѭ��ִ��
        select @sql1=
        ' select @a=' 
        +results from [#tmp] where res=@ii1
        
       
        exec sp_executesql @sql1,N'@a numeric(18,4) output',@rs1 output
    
        --����#tmp����
        update x set  results1=@rs1
        from #tmp as x 
        where x.res=@ii1
        
        --print (@rs1)
        --ѭ��ֵ+1
        set @ii1=@ii1+1
           end    --1.2.1
        
        --ѭ����֮��   ���ݽ�� ˢ����ϸ��¼
     
        --select * from #tmp1
        update y set gcom=x.results1
        from #tmp as x inner join  #adminuser as y 
        on x.ShiftID=y.ShiftID and x.dates=y.ScheData and x.salerlevel=y.salerlevel
         
          --select 1 as types,* from #tmp
       
     end  --1.2

--print '����ֵ:'+cast(@n as varchar(20))
--��ѭ��ֵ+1


set @i=@i+1
end    --1
--ɾ��#tmp��


--������˽Ӷ  ���Ű�ļ�¼ ���쳣��¼  �Ű��BussScheDetail�޼�¼  ����orde_s���м�¼��	

insert into #adminuser(agentid,AdminUserName,ShiftID,ShiftName,ScheData,salerlevel,gcom,pcom)
select y.sagentid,y.SalesName,y.shiftid,y.shiftname,y.dates,y.salerlevel
,0    --�쳣��¼ �����빫Ӷ  ��Ӷ����ǰ��������
,y.pcom   --˽Ӷ��¼
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



--select * from #temp      --������ϸ����  ÿ�ʹ�˽Ӷ��ϸ
--select * from #ComCateCale     --���������
--select * from #Pcom            --��Ӷ�ϼ�
--select * from #adminuser       --Ա���Ű���ϸ+��Ӷ��ϸ
--select * from #shiftcount      --Ա���Ű�ͳ�ƣ���ְλ��
--select * from #ComStaffCale    --���㹫ʽ
--select * from #ComStaffCalePerson   --��ʽԱ��  ��ת��





-------------------------------------------------------------
-------------------------------------------------------------
-------------------------------------------------------------
--ɾ��Ӷ�������StaffCom ������ȱ������Ĺ��� agentid
--select * 
----delete x 
--from StaffCom as x 
--where 1=1 
----ȱ������  ���ݻ�δ�滻 
--and saledate>='2016-12-01 00:00:00' and saledate<='2016-12-31 23:59:59'



--����Ӷ�������StaffCom   select * from StaffCom
--insert into StaffCom(SalerID,SaleDate,GetMoney,GetType,ShiftID)
select --x.agentid,
AdminUserID as userid,ScheData as SaleDate,pcom GetMoney,2 GetType,ShiftID from #adminuser as x
left join AdminUser as y on x.AdminUserName=y.AdminUserName
union all 
select --x.agentid,
AdminUserID,ScheData,gcom,1,ShiftID from #adminuser as x
left join AdminUser as y on x.AdminUserName=y.AdminUserName


 
 
 
------�����ʱ��
--    drop table #tmp
--    drop table #temp      --������ϸ����  ÿ�ʹ�˽Ӷ��ϸ
--    drop table #ComCateCale     --���������
--    drop table #Pcom            --��Ӷ�ϼ�
--    drop table #adminuser       --Ա���Ű���ϸ+��Ӷ��ϸ
--	drop table #shiftcount      --Ա���Ű�ͳ�ƣ���ְλ��
--	drop table #ComStaffCale    --���㹫ʽ
--	drop table #ComStaffCalePerson   --��ʽԱ��  ��ת��
	
	
 
 
 

--Ӷ�������ϸ����
select OrderNo ���۵���,dates ����,ShiftName ������,SaleGroup �������,ODQuantity ����,ODBarcode ����,CateName ���
,rates as [��׼����(����|�ۿ�)],typess �����׼,right(cast(cast(round(calrate,2) as numeric(18,2)) as varchar(20)),20)+'%' ������
,ODRealSalePrice ʵ�ۼ�
,oldsaleprice �ɽ���
,gcom ��Ӷ,pcom ˽Ӷ
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
