/****** Object:  UserDefinedFunction [dbo].[deduplicate4gram_simple]    
Script Date: 6/17/2020 4:25:05 PM 
Developed by Hasan Zafari
******/
-- An example of how to call the function. The deduplicate4gram function takes a patient_id and an encounter# and de-duplicates the next encounter with respect to the current one. For example, the following call de-duplicates the repeated contents of the encounter notes number 25 with respect to the encounter notes number 24 and returns the remaining part
   -- select [dbo].[deduplicate4gram](80070042235,24)
-- This function depends on some other functions that are defined following.

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
Create function [dbo].[deduplicate4gram_simple](@pid decimal, @enc# int)
   returns varchar(8000)
   as
   begin

	Declare @note1 varchar(8000),@note2 varchar(8000),@out varchar(1000),@sub_st varchar(120),@out_final varchar(1000)
	Declare @Num_of_common_words int

    set @out=''
	SELECT @note1=[content2] FROM [EncounterNotesExp] where Patient_ID=@pid and [encounter#]=@enc#
	SELECT @note2=[content2] FROM [EncounterNotesExp] where Patient_ID=@pid and [encounter#]=@enc#+1

       DECLARE @diff_tbl TABLE 
(
    [Value] VARCHAR(max)
)
 insert into @diff_tbl
  SELECT  value FROM remain_str_tbl_fourgram(@pid,@enc#)-- calculate the difference between note2 (the longest) and note1 (the shortest), i.e. note2-note1

   

 DECLARE @out_tbl TABLE ([Value] VARCHAR(max), ord int)
 insert into @out_tbl([Value],ord)-- we have to create this table first and then use in the joint along with ord to ensure keeping the order of the original sentence
 SELECT value,ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) as ord
  FROM [dbo].[fourgram](@note2)

  declare @fourGram varchar(100),@fourGram_pre varchar(100),@last_word varchar(100),@deduplicated_out varchar(8000),@temp_rsu varchar(8000)
  declare @is_null int,@is_not_null int
  set @deduplicated_out=''
  set @temp_rsu=''
  set @fourGram_pre=null
  set @is_null=0
  set @is_not_null=0

----------------------------------------
 DECLARE code_crsr CURSOR
FOR  select v2 from
    (SELECT [value] v1,ord FROM @out_tbl)a 
full outer join 
   (SELECT  value v2 FROM @diff_tbl ) b 
  on a.v1=b.v2
  order by ord
  
OPEN code_crsr;
FETCH NEXT FROM code_crsr INTO @fourGram
WHILE @@FETCH_STATUS = 0
  BEGIN
   if @fourGram is not null --and @k>0
    begin
     set @last_word=(select dbo.getLastWord(@fourGram))
     set @temp_rsu=@temp_rsu+@last_word
	end
   
   if @fourGram is null
   begin
    set @is_null=@is_null+1
	
	if @is_not_null<=4 and @is_not_null>0
	 begin
	  set @deduplicated_out=@deduplicated_out+' '+substring(@temp_rsu,0,charindex(' ',ltrim(@temp_rsu))+1)
	  set @temp_rsu=''
     end
	 else
	  if @temp_rsu<>''
	   begin
	    set @deduplicated_out=@deduplicated_out+' '+@temp_rsu
		set @temp_rsu=''
      end

	set @is_not_null=0
   end
   else
   if @fourGram is not null
   begin
    set @is_not_null=@is_not_null+1
	set @is_null=0
   end
   
  FETCH NEXT FROM code_crsr INTO @fourGram
  end
CLOSE code_crsr;
DEALLOCATE code_crsr;
 if @temp_rsu<>''
      set @deduplicated_out=@deduplicated_out+' '+@temp_rsu
return @deduplicated_out
   end





------------------------------------------------- Required functions ----------------------------------------
/****** Object:  UserDefinedFunction [dbo].[remain_str_tbl_fourgram]    Script Date: 6/17/2020 4:36:11 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
Create FUNCTION [dbo].[remain_str_tbl_fourgram](@pid decimal, @enc# int)
RETURNS @Data TABLE 
(
    [Value] VARCHAR(max)
)
AS
BEGIN 
   INSERT INTO @Data 
   -- SELECT value from(
	SELECT  value from [dbo].[fourgram]((SELECT [content2] FROM EncounterNotesExp where Patient_ID=@pid and  [encounter#]=@enc#+1)) where ltrim(value)<>''
   except
   SELECT  value from [dbo].[fourgram]((SELECT [content2] FROM EncounterNotesExp where Patient_ID=@pid and  [encounter#]=@enc#)) where ltrim(value)<>''
 ---	)
    RETURN 
END


--------------------------------------- get last word ----------------------
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
Create function [dbo].[getLastWord](@s varchar(100))
returns varchar(200)
as
begin
declare @i int
set @i=len(@s)
 while substring(@s,@i,1)<>' '
  set @i=@i-1
 return substring(@s,@i,len(@s)-@i+1)
 end









----------------------------------------------------- Generate fourGrams -----------------------------------------

/****** Object:  UserDefinedFunction [dbo].[fourgram]    Script Date: 6/17/2020 4:37:57 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
Create FUNCTION [dbo].[fourgram](@note varchar(max))
RETURNS @Data TABLE 
( [Value] VARCHAR(max))
AS
BEGIN 
/*if (SELECT  count(value) FROM STRING_SPLIT(@note, ' ') where ltrim(value)<>'')<4 
 return 
*/
set @note=REPLACE(@note,',',' , ')
set @note=REPLACE(@note,';',' ; ')
set @note=REPLACE(@note,'.',' . ')
set @note=REPLACE(@note,':',' : ')
set @note=REPLACE(@note,'-',' _ ')
Declare @w1 varchar(50),@w2 varchar(50),@w3 varchar(50),@w4 varchar(50)
DECLARE code_crsr CURSOR
FOR SELECT  value FROM STRING_SPLIT(@note, ' ') where ltrim(value)<>''
OPEN code_crsr;
/*
FETCH NEXT FROM code_crsr INTO @w1
FETCH NEXT FROM code_crsr INTO @w2
FETCH NEXT FROM code_crsr INTO @w3
FETCH NEXT FROM code_crsr INTO @w4
*/
set @w1=''
set @w2=''
set @w3=''
FETCH NEXT FROM code_crsr INTO @w4
WHILE @@FETCH_STATUS = 0
  BEGIN
  	 INSERT INTO @Data values(ltrim(@w1+' '+@w2+' '+@w3+' '+@w4))
	 --FETCH NEXT FROM code_crsr INTO @w2
	 set @w1=@w2
	 set @w2=@w3
	 set @w3=@w4
    FETCH NEXT FROM code_crsr INTO @w4
  end
CLOSE code_crsr;
DEALLOCATE code_crsr;

     RETURN 
END

-- select * from [dbo].[fourgram]('Feels things getting worse. Low motivation, feels that he has trouble doing ADLs')
