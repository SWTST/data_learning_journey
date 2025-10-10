
# Production Query used in CEV Refresh step "Jobs"

The base query pulls data in via linked server and executes in 02:53 returning 1,867,121 rows. The execution plan is below: [hmsstg.jobs (Query 1)](../hmstsgjobq1.sqlplan)

```
-- Runtime: 02:53
-- Rows: 1,867,121 
SELECT DISTINCT
  a.num,
  LEFT(a.[dpt-cde],3) [dpt_cde],
  a.[pr-seq-no] [pr_seq_no],
  a.[contr-cde] [contr_cde],
  LEFT(a.[pty-cde],1) [pty_cde],
  LEFT(a.[jobsts-cde],2) [jobsts_cde],
  a.[reported-dat] [reported_dat],
  a.[contr-oot-days] [contr_oot_days],
  a.[contr-oot-hours] [contr_oot_hours],
  a.[pre-inspect-oot-days] [pre_inspect_oot_days],
  a.[post-inspect-oot-days] [post_inspect_oot_days],
  a.[practical-completion-dat] [practical_completion_dat],
  within_target =
   CASE
       WHEN a.[practical-completion-dat] IS NULL THEN
           CASE
              WHEN dateadd(ss,[practical-completion-tim],cast([practical-completion-dat] as datetime)) > dateadd(ss,[overall-target-tim],cast([overall-target-dat] as datetime)) THEN
                 'N'
              ELSE
                  'U'
            END
      ELSE
           CASE
              WHEN dateadd(ss,[practical-completion-tim],cast([practical-completion-dat] as datetime)) > dateadd(ss,[overall-target-tim],cast([overall-target-dat] as datetime)) THEN
                 'N'
              ELSE
                  'Y'
            END
   END,
  completed =
   CASE
       WHEN a.[practical-completion-dat] IS NULL THEN 0
       ELSE 1
   END,
   in_target =
        CASE
          WHEN a.[practical-completion-dat] IS NULL THEN
           CASE
              WHEN dateadd(ss,[practical-completion-tim],cast([practical-completion-dat] as datetime)) > dateadd(ss,[overall-target-tim],cast([overall-target-dat] as datetime)) THEN
                0
              ELSE
                  NULL
            END
      ELSE
           CASE
              WHEN dateadd(ss,[practical-completion-tim],cast([practical-completion-dat] as datetime)) > dateadd(ss,[overall-target-tim],cast([overall-target-dat] as datetime)) THEN
                 0
              ELSE
                  1
            END
   END,
out_target =
      CASE
            WHEN a.[practical-completion-dat] IS NULL THEN
           CASE
              WHEN dateadd(ss,[practical-completion-tim],cast([practical-completion-dat] as datetime)) > dateadd(ss,[overall-target-tim],cast([overall-target-dat] as datetime)) THEN
               1
              ELSE
                  NULL
            END
      ELSE
           CASE
              WHEN dateadd(ss,[practical-completion-tim],cast([practical-completion-dat] as datetime)) > dateadd(ss,[overall-target-tim],cast([overall-target-dat] as datetime)) THEN
                 1
              ELSE
                  0
            END
   END ,
--   'Y' [Cancelled],
	'N' [Cancelled],
	LEFT(a.[sortrd-cde-1] ,2) [trade_type]
   ,a.[overall-oot-days] [overall_oot_days]
  ,a.[overall-oot-hours] [overall_oot_hours]
   ,a.[overall-target-dat] [overall_target_date]
   ,a.[contr-target-dat] [contr_target_date]
   ,LEFT(LEFT((cast(a.[dsc@1] as varchar(204))+';'+cast(a.[dsc@2] as varchar(204))  collate database_default),CHARINDEX(';',(cast(a.[dsc@1] as varchar(204))+';'+cast(a.[dsc@2] as varchar(204))  collate database_default)) - 1),50) [problem_desc1]
  ,LEFT(RIGHT((cast(a.[dsc@1] as varchar(204))+';'+cast(a.[dsc@2] as varchar(204))  collate database_default), LEN((cast(a.[dsc@1] as varchar(204))+';'+cast(a.[dsc@2] as varchar(204))  collate database_default)) - CHARINDEX(';',(cast(a.[dsc@1] as varchar(204))+';'+cast(a.[dsc@2] as varchar(204))  collate database_default))),50) [problem_desc2]
  ,a.[reported-by-nam] [reported_by_name]
  ,a.[void-num] [void_num]
  ,dbo.hfn_TimeBy24Hour(a.[overall-target-tim]) target_time
  ,dbo.hfn_TimeBy24Hour(a.[reported-tim]) reported_time
  ,dbo.hfn_TimeBy24Hour(a.[practical-completion-tim]) completed_time
/* CR193164 */
--,a.[tot-val]
, days_over_target_date =
         CASE
                 WHEN a.[practical-completion-dat] IS NULL THEN
                                           DATEDIFF(d,a.[overall-target-dat],GETDATE())
              ELSE
                        CASE 
                           WHEN (a.[overall-target-dat] IS NOT NULL) AND (a.[practical-completion-dat] > a.[overall-target-dat]) THEN
                                 DATEDIFF(d,a.[overall-target-dat],a.[practical-completion-dat])
                            ELSE
                                  0
                         END
              END
,a.[sor-val] + a.[non-sor-val] job_cost
/* end CR193164 */
,a.[exptyp-cde] charge_to_code
,a.[last-var-no] last_var_no
,(a.[non-sor-invoice-val] + a.[sor-invoice-val]) invoiced_cost
,a.[expenditure-cde] expenditure_code
-- 11/05/2006
,a.[con-num] contract_num
-- 08/02/2007
,a.[access-note] access_note
FROM imsdb.ims@staging.hmsstg.job a (nolock)
LEFT JOIN [orchard_jobs_fact] c
ON  a.[dpt-cde] = c.[dpt_cde] collate database_default
AND a.[num] BETWEEN c.[start_num] AND c.[end_num]
WHERE (a.[reported-dat] >= (case when MONTH(GETDATE()) < = 3 then DATEFROMPARTS(YEAR(GETDATE()) -7,4,1) else DATEFROMPARTS(YEAR(GETDATE()) -6,4,1) end) 
and a.[practical-completion-dat] is not null) 
or a.[practical-completion-dat] is null
```
Steps taken below to decrease runtime and prevent dirty reads:
1. Removed JOIN to [orchard_jobs_fact] as this was unused
2. Removed (nolock) to prevent dirty reads
3. Wrapped query in an OPENQUERY to move processing to remote server and bring only the final data we need over linked server connection

```
-- Runtime: 00:58
-- Rows: 1,867,121
SELECT *
FROM OPENQUERY(imsdb, '
SELECT DISTINCT
  a.num,
  LEFT(a.[dpt-cde],3) AS dpt_cde,
  a.[pr-seq-no] AS pr_seq_no,
  a.[contr-cde] AS contr_cde,
  LEFT(a.[pty-cde],1) AS pty_cde,
  LEFT(a.[jobsts-cde],2) AS jobsts_cde,
  a.[reported-dat] AS reported_dat,
  a.[contr-oot-days] AS contr_oot_days,
  a.[contr-oot-hours] AS contr_oot_hours,
  a.[pre-inspect-oot-days] AS pre_inspect_oot_days,
  a.[post-inspect-oot-days] AS post_inspect_oot_days,
  a.[practical-completion-dat] AS practical_completion_dat,
  CASE
    WHEN a.[practical-completion-dat] IS NULL THEN
      CASE
        WHEN DATEADD(ss,[practical-completion-tim],CAST([practical-completion-dat] AS datetime)) > DATEADD(ss,[overall-target-tim],CAST([overall-target-dat] AS datetime)) THEN ''N''
        ELSE ''U''
      END
    ELSE
      CASE
        WHEN DATEADD(ss,[practical-completion-tim],CAST([practical-completion-dat] AS datetime)) > DATEADD(ss,[overall-target-tim],CAST([overall-target-dat] AS datetime)) THEN ''N''
        ELSE ''Y''
      END
  END AS within_target,
  CASE
    WHEN a.[practical-completion-dat] IS NULL THEN 0
    ELSE 1
  END AS completed,
  CASE
    WHEN a.[practical-completion-dat] IS NULL THEN
      CASE
        WHEN DATEADD(ss,[practical-completion-tim],CAST([practical-completion-dat] AS datetime)) > DATEADD(ss,[overall-target-tim],CAST([overall-target-dat] AS datetime)) THEN 0
        ELSE NULL
      END
    ELSE
      CASE
        WHEN DATEADD(ss,[practical-completion-tim],CAST([practical-completion-dat] AS datetime)) > DATEADD(ss,[overall-target-tim],CAST([overall-target-dat] AS datetime)) THEN 0
        ELSE 1
      END
  END AS in_target,
  CASE
    WHEN a.[practical-completion-dat] IS NULL THEN
      CASE
        WHEN DATEADD(ss,[practical-completion-tim],CAST([practical-completion-dat] AS datetime)) > DATEADD(ss,[overall-target-tim],CAST([overall-target-dat] AS datetime)) THEN 1
        ELSE NULL
      END
    ELSE
      CASE
        WHEN DATEADD(ss,[practical-completion-tim],CAST([practical-completion-dat] AS datetime)) > DATEADD(ss,[overall-target-tim],CAST([overall-target-dat] AS datetime)) THEN 1
        ELSE 0
      END
  END AS out_target,
  ''N'' AS Cancelled,
  LEFT(a.[sortrd-cde-1],2) AS trade_type,
  a.[overall-oot-days] AS overall_oot_days,
  a.[overall-oot-hours] AS overall_oot_hours,
  a.[overall-target-dat] AS overall_target_date,
  a.[contr-target-dat] AS contr_target_date,
  LEFT(LEFT(CAST(a.[dsc@1] AS varchar(204)) + '';'' + CAST(a.[dsc@2] AS varchar(204)), CHARINDEX('';'', CAST(a.[dsc@1] AS varchar(204)) + '';'' + CAST(a.[dsc@2] AS varchar(204))) - 1), 50) AS problem_desc1,
  LEFT(RIGHT(CAST(a.[dsc@1] AS varchar(204)) + '';'' + CAST(a.[dsc@2] AS varchar(204)), LEN(CAST(a.[dsc@1] AS varchar(204)) + '';'' + CAST(a.[dsc@2] AS varchar(204))) - CHARINDEX('';'', CAST(a.[dsc@1] AS varchar(204)) + '';'' + CAST(a.[dsc@2] AS varchar(204)))), 50) AS problem_desc2,
  a.[reported-by-nam] AS reported_by_name,
  a.[void-num] AS void_num,
  a.[overall-target-tim] AS target_time,
  a.[reported-tim] AS reported_time,
  a.[practical-completion-tim] AS completed_time,
  CASE
    WHEN a.[practical-completion-dat] IS NULL THEN DATEDIFF(d, a.[overall-target-dat], GETDATE())
    ELSE
      CASE
        WHEN a.[overall-target-dat] IS NOT NULL AND a.[practical-completion-dat] > a.[overall-target-dat] THEN DATEDIFF(d, a.[overall-target-dat], a.[practical-completion-dat])
        ELSE 0
      END
  END AS days_over_target_date,
  a.[sor-val] + a.[non-sor-val] AS job_cost,
  a.[exptyp-cde] AS charge_to_code,
  a.[last-var-no] AS last_var_no,
  a.[non-sor-invoice-val] + a.[sor-invoice-val] AS invoiced_cost,
  a.[expenditure-cde] AS expenditure_code,
  a.[con-num] AS contract_num,
  a.[access-note] AS access_note
FROM ims@staging.hmsstg.job a
WHERE (a.[reported-dat] >= CASE WHEN MONTH(GETDATE()) <= 3 THEN DATEFROMPARTS(YEAR(GETDATE()) - 7, 4, 1) ELSE DATEFROMPARTS(YEAR(GETDATE()) - 6, 4, 1) END
       AND a.[practical-completion-dat] IS NOT NULL)
   OR a.[practical-completion-dat] IS NULL
')
```