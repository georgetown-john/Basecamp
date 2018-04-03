
/**********************************************************************************************************************/
/*  Dashboard Migration -- GU360:  DOs Key Operating Metrics                                                          */
/*  Migrate, and integrate w                                                                                          */
/*                                                                                                                    */
/*  Date Created:  Jan 04, 2018                                                                                       */
/*  Last Modified: March 29, 2018 v5                                                                                  */
/**********************************************************************************************************************/

/***** I.  Step 1: Create a 'qryContacts' (include source data references, i.e 'AdvancementActivities')   *****/

  --  Create 'qryContacts' view analogous to that from PRM (but only with fields needed)
CREATE VIEW [Analytics\tableau].qryContacts AS

  WITH qry_contacts_DO AS
  (
    Select
      OwnerId                  as do_id, --note: check against OwnerId__c(?)
      ActivityDate__c          as actcompdat,
      Type__c                  as actcontvalue,
      Type__c                  as actactivity, -- same field but renamed again to mimic PRM's qryContacts
      Substantive_Activity__c  as Substantive_Activity,
      Status__c                as actcategory,
      Description__c           as actcomm,
      ownerName                as taskcontactor,
      (UPPER(ownerLastName)+'/'+UPPER(ownerFirstName)) as taskcontactorsort,
      Related_Account__c       as Account_ID,
      Id                       as activity_id,
      Advancement_Activity__c  as activity_id_rc,
      Contact_rc               as contact_id_rc,
      contactor_number         as contactor_number,
      contactor                as contactor

    From (
          Select  aa.OwnerId, aa.Type__c, aa.ActivityDate__c, aa.Substantive_Activity__c, aa.Status__c,
                  aa.Description__c, aa.Id, rc.Advancement_Activity__c, aa.Related_Account__c,
                  owner_user.Name ownerName, owner_user.LastName ownerLastName, owner_user.FirstName ownerFirstName,
                  rc.Contact__c Contact_rc, aa.OwnerId__c contactor_1, aa.Assigned_To_2__c contactor_2,
                  aa.Assigned_To_3__c contactor_3
            From [salesforce backups].dbo.Advancement_Activity__c aa
            Left Outer Join [salesforce backups].dbo.[User] owner_user  -- get all user IDs for last Owner
                On owner_user.Id = aa.OwnerId
            Left Outer Join [salesforce backups].dbo.Advancement_Activity_Related_Contacts__c rc -- get related contacts
                On rc.Advancement_Activity__c = aa.Id
            Where owner_user.Name <> 'Carole Hornik'  --exclude because Visit counts way too high (major data prob)
                And Type__c in ('Visit', 'Visit Assist')
         ) subq
         Unpivot
            (contactor For contactor_number In
              (contactor_1, contactor_2, contactor_3)
            ) unpvt
  )

SELECT *
  From qry_contacts_DO
GO;
-------

/*-----------------------------------------------------------------  End Code  -----------------------------------------------------------------*/

/***** II.  Step 2: Create a 'qryProposal' (include source data references, i.e 'tblProposal', 'tblProspect')   *****/


  -- Create 'qryProposal' view analogous to that from PRM (but only with fields needed)
CREATE VIEW [Analytics\tableau].qryProposal AS

  WITH qry_proposal_DO AS
  (
    Select
      opp.OwnerId                 as do_id, --note: check against OwnerId__c(?)
      opp.Lead_Solicitor__c       as Lead_Solicitor_ID,
      opp.Ask_Date__c             as ask_date,
      opp.Ask_Amount__c           as ask_amt,
      opp.Amount                  as gift_amt,
      opp.CloseDate               as gift_date,
      optm.Name                   as solicitor,
      optm.TeamMemberRole         as solicitor_level,
      opp.Name                    as gift_name, --follow up/note that there is no one for one match of proppurpos?
      opp.Division__c             as gift_unit,
      --all fields below: add'l fields that come after the core, good for future ref.
      opp.Id                      as OpportunityID,
      opp.StageName               as StageName,
      opp.AQB__Comment__c         as Comment,
      opp.AccountId               as AccountID,
      acc.Name                    as AccountName


    From [salesforce backups].dbo.Opportunity AS opp
    Left Outer Join [salesforce backups].dbo.OpportunityTeamMember AS optm
      On opp.Id = optm.OpportunityId
    Left Outer Join (Select Name, Id from [salesforce backups].dbo.Account) acc
      On opp.AccountId = acc.Id
  )

SELECT *
  From qry_proposal_DO
GO;
-------


/*-----------------------------------------------------------------  End Code  -----------------------------------------------------------------*/


/***** III.  Step 3: Create Final Results of comb_hh_capacities Migration     *****/


CREATE VIEW [Analytics\tableau].comb_hh_capacities AS

    SELECT DISTINCT Id as Account_ID,
        CASE
          WHEN x.gu_capacity_range = 0 THEN
              Case
                  When x.gga_capacity_range = 1    Then '1 Transformative Prospect ($10M+)'
                  When x.gga_capacity_range = 2    Then '2 Principal Prospect ($5M-$10M)'
                  When x.gga_capacity_range = 3    Then '3 Leadership Prospect ($1M-$5M)'
                  When x.gga_capacity_range = 4    Then '4 Major Gift Prospect ($100K-$1M)'
                  When x.gga_capacity_range = 5    Then '5 Special Gift Prospect ($25K-$100K)'
                  When x.gga_capacity_range = 6    Then '6 Annual Gift Prospect (<$25K)'
                  Else 'No Capacity Assigned'
              END
          ELSE
              Case
                  When x.gu_capacity_range = 1   Then '1 Transformative Prospect ($10M+)'
                  When x.gu_capacity_range = 2   Then '2 Principal Prospect ($5M-$10M)'
                  When x.gu_capacity_range = 3   Then '3 Leadership Prospect ($1M-$5M)'
                  When x.gu_capacity_range = 4   Then '4 Major Gift Prospect ($100K-$1M)'
                  When x.gu_capacity_range = 5   Then '5 Special Gift Prospect ($25K-$100K)'
                  When x.gu_capacity_range = 6   Then '6 Annual Gift Prospect (<$25K)'
                  Else 'No Capacity Assigned'
               End
        END comb_capacity_range,

        CASE                                                        --careful GGA_Category__c & Segment__c
          WHEN x.gu_capacity_range = 0 And x.gga_capacity_range = 0 Then Null
          WHEN x.gu_capacity_range = 0 Then 'GG+A'
          ELSE 'GU Research'
        END comb_capacity_source

    FROM
      ( SELECT c.Id, max(c.gga_capacity_range) gga_capacity_range, max(c.gu_capacity_range) gu_capacity_range
          FROM
          (
            Select acc.Id,
              Case      --note: can also use GGA_Category__c
                  When pr.Segment__c = '$10 million or more'                                                     Then 1
                  When pr.Segment__c = '$5,000,000 to $9,999,999'                                                Then 2
                  When pr.Segment__c = '$1,000,000 to $4,999,999'                                                Then 3
                  When pr.Segment__c in ('$100,000 to $249,999', '$250,000 to $499,999', '$500,000 to $999,999') Then 4
                  When pr.Segment__c in ('$25,000 to $49,999', '$50,000 to $99,999')                             Then 5
                  When pr.Segment__c in ('$1,000 - $2,499', '$100 - $499', '$2,500 - $4,999', '$2,500 to $9,999',
                                         '$5,000+','$500 - $999', 'Institution Min Under $100')                  Then 6
                  Else 0
              End gga_capacity_range,

              Case
                  When acc.Capacity_MG_Capacity__c >= 10000000                                             Then 1
                  When acc.Capacity_MG_Capacity__c <  10000000 And acc.Capacity_MG_Capacity__c >= 5000000  Then 2
                  When acc.Capacity_MG_Capacity__c <  5000000  And acc.Capacity_MG_Capacity__c >= 1000000  Then 3
                  When acc.Capacity_MG_Capacity__c <  1000000  And acc.Capacity_MG_Capacity__c >= 100000   Then 4
                  When acc.Capacity_MG_Capacity__c <  100000   And acc.Capacity_MG_Capacity__c >= 25000    Then 5
                  When acc.Capacity_MG_Capacity__c <  25000    And acc.Capacity_MG_Capacity__c >= 1000     Then 6
                  Else 0
              End gu_capacity_range

              From [salesforce backups].dbo.Account acc
              Left Join [salesforce backups].dbo.Prospect_Rating__c pr
                    On acc.Id = pr.Account__c
              Left Join [salesforce backups].dbo.RecordType rt
                    On rt.Id = pr.RecordTypeId

          Where (rt.Name in ('GGA', 'Gu Capacity') or rt.Name is Null) -- account for it in case staements
            And acc.AQB__AccountStatus__c = 'Active'
          ) c

    Group By c.Id ) x

GO;
-------
/*-----------------------------------------------------------------  End Code  -----------------------------------------------------------------*/


/***** IV.  Step 4: do_name_key     *****/
CREATE VIEW [Analytics\tableau].do_name_key AS

  WITH donamekey_main as
  (
    Select 	dm.User__c 						                  as do_id,
	    	    ( us.FirstName + ' ' + us.LastName  )   as first_last,
		        ( us.LastName  + ' ' + us.FirstName )   as last_first,
		        dt.Name               			            as do_team,     --Development_Teams__c Object has names
		        dm.DO_Level__c  				                as do_level,     --note: (necessary?) missing "Law"
          ( us.LastName  + ', ' + us.FirstName ) as last_first_comma,
          Case When (dt.Name = 'GUMC Education & Research' Or dt.Name = 'Lombardi' Or dt.Name = 'GULC'
                          Or dt.Name = 'Planned Giving' Or dt.Name = 'Corporate & Foundation Relations')
              Then 'Y'
          End count_all_flag

      /*Into [Salesforce Dev].[Analytics\tableau].do_name_key*/


      From [salesforce backups].dbo.DO_Management__c dm  --note: no Jonathan Price as of Feb. 12, 2018 (DO_Management__c)
      Left Outer Join [salesforce backups].dbo.[User] us     --therefore, Jonathan Price does not have a development team
          ON us.Id = dm.User__c
      Left Outer Join [salesforce backups].dbo.Development_Teams__c dt
          ON dm.Development_Teams__c = dt.Id
  ) ,

  do_nk_hardw as --hardcode Jonathan Price for now until Zibing adds him to DO_Management__c
  (
    Select '00536000007kjmSAAQ'   as do_id,
           'Jonathan Rice'        as first_last,
           'Rice Jonathan'        as last_first,
           'Planned Giving'       as do_team,
           'DOD'                  as do_level,
           'Rice, Jonathan'       as last_first_comma,
           'Y'                    as count_all_flag
  )
SELECT * From donamekey_main /*Into [Salesforce Dev].[Analytics\tableau].do_name_key From donamekey_main*/
  Union All
SELECT * From do_nk_hardw
GO;
-------
/*-----------------------------------------------------------------  End Code  -----------------------------------------------------------------*/


/***** V.  Step 5: Create Final activity_list    *****/

  -- Drop view if exists for future rewrite purposes --
IF OBJECT_ID('[Analytics\tableau].activity_list') IS NOT NULL
    DROP VIEW [Analytics\tableau].activity_list;
GO;

  -- Use CTE structure to for better readability and commenting --
CREATE VIEW [Analytics\tableau].activity_list AS

  WITH

   DO_advmnt_actvts AS   -- key data fields for advancement activities
    ( Select
      OwnerId                  as OwnerID,
      ownerName     				   as OwnerName,
      Type__c                  as ActivityType,
      Description__c           as Activity_Description,
      ActivityDate__c          as ActivityDate,
      Related_Account__c       as AccountID,
      Status__c                as ActivityStatus,
      Substantive_Activity__c  as Substantive_Activity,
      Advancement_Activity__c  as activity_id_rc,
      contactor_number         as contactor_number,
      contactor                as contactor,
      related_contact          as related_contact,
      contact                  as contact,
      cont_user.Name           as contactor_name,
      Subject__c               as Subject__c
      From  (  --unpivot to get Related Contacts visits
            Select  aa.OwnerId, aa.Type__c, aa.ActivityDate__c, aa.Substantive_Activity__c, aa.Status__c,
                    aa.Description__c, aa.Id, rc.Advancement_Activity__c, aa.Related_Account__c,
                    owner_user.Name ownerName, rc.Contact__c Contact_rc, aa.OwnerId__c contactor_1,
                    aa.Assigned_To_2__c contactor_2, aa.Assigned_To_3__c contactor_3, aa.Subject__c, aa.WhoId__c WhoId__c
                From [salesforce backups].dbo.Advancement_Activity__c aa
                Left Outer Join [salesforce backups].dbo.[User] owner_user  -- get all user IDs for last Owner
                    On owner_user.Id = aa.OwnerId
                Left Outer Join [salesforce backups].dbo.Advancement_Activity_Related_Contacts__c rc -- get related contacts
                    On rc.Advancement_Activity__c = aa.Id
                Where owner_user.Name <> 'Carole Hornik'  --exclude because Visit counts way too high (major data prob)
                    /*And Type__c in ('Visit', 'Visit Assist')*/
            ) subq

            Unpivot
              (contactor For contactor_number In
              (contactor_1, contactor_2, contactor_3)
              ) unpvt
            Unpivot
              (contact For related_contact In
              (WhoId__c, Contact_rc)
              ) unpvt2

            Left Outer Join [salesforce backups].dbo.[User] cont_user
                On contactor = cont_user.Id
    )  ,

    DO_opportunities AS
    ( Select
        opp.OwnerId                 as OwnerID, --note: check against OwnerId__c(?)
        opp.Ask_Date__c             as ask_date,
        opp.Ask_Amount__c           as ask_amt,
        opp.Amount                  as gift_amt,
        opp.CloseDate               as gift_date,
        optm.Name                   as optm_name,
        optm.TeamMemberRole         as solicitor_level,
        opp.Name                    as gift_name, --follow up/note that there is no one for one match of proppurpos?
        opp.Division__c             as gift_unit,
        --all fields below: add'l fields that come after the core, good for future ref.
        opp.StageName               as StageName,
        opp.Id                      as OpportunityID,
        opp.AccountId               as AccountID,
        opp.AQB__Comment__c         as Comment,
        opp.Lead_Solicitor__c       as lead_solicitor_ID,
        optm.UserId                 as optm_userID,
        --fy18 to fy15 gifts when Lead Solicitor
        Case When opp.StageName in ('Accepted', 'Accepted - Stewardship')
                And optm.TeamMemberRole='Lead Solicitor' And opp.CloseDate between '2017-07-01' and '2018-06-30'
            Then opp.Amount
        End fy18_gift_amount,
        Case When opp.StageName in ('Accepted', 'Accepted - Stewardship')
                And optm.TeamMemberRole='Lead Solicitor' And opp.CloseDate between '2016-07-01' and '2017-06-30'
            Then opp.Amount
        End fy17_gift_amount,
        Case When opp.StageName in ('Accepted', 'Accepted - Stewardship')
                And optm.TeamMemberRole='Lead Solicitor' And opp.CloseDate between '2015-07-01' and '2016-06-30'
            Then opp.Amount
        End fy16_gift_amount,
        Case When opp.StageName in ('Accepted', 'Accepted - Stewardship')
                And optm.TeamMemberRole='Lead Solicitor' And opp.CloseDate between '2014-07-01' and '2015-06-30'
            Then opp.Amount
        End fy15_gift_amount
        /*nk.first_last               as first_last,
        nk.last_first               as last_first,
        nk.last_first_comma         as last_first_comma*/

      From [salesforce backups].dbo.Opportunity opp
      Left Outer Join [salesforce backups].dbo.OpportunityTeamMember optm
          On opp.Id = optm.OpportunityId
      /*Left Outer Join [Salesforce Dev].[Analytics\tableau].do_name_key nk
          On nk.do_id = opp.Lead_Solicitor__c*/
    ) ,

    DO_visits as  -- logical flow for DO visits --
    ( Select
        adac.AccountID              as AccountID,
        acc.Name                    as hh_name,
        acc.AQB__District__c        as market, --check back on AQB__District__c to make sure it's the right field in future
        nk.do_id                    as do_id,
        Case
          When Month(adac.ActivityDate) >= 7 Then Year(adac.ActivityDate) + 1
          Else Year(adac.ActivityDate)
        End comb_fy,
        adac.ActivityDate           as visit_date,
        adac.Activity_Description   as visit_summ,
        adac.contactor_name         as visitor,
        --the ask fields below are placeholders
        Null                        as ask_amt,
        Null                        as ask_date,
        Null                        as gift_amt,
        Null                        as gift_date,
        Null                        as solicitor,
        Null                        as solicitor_level,
        Null                        as gift_name,
        Null                        as gift_unit,
        'visits'                    as source,
        --all fields below: add'l fields that come after the core 17 fields -- for future ref.
        adac.ActivityStatus         as ActivityStatus,
        Null                        as StageName,
        Null                        as lead_solicitor_ID,
        nk.first_last               as first_last,
        nk.last_first               as last_first,
        nk.last_first_comma         as last_first_comma,
        adac.contactor              as contactor,
        adac.contactor_name         as contactor_name,
        adac.Subject__c             as Subject__c,
        Null                        as gift_amt_comb_lead_sec,
        Null                         fy_18_gift_amount,
        Null                         fy_17_gift_amount,
        Null                         fy_16_gift_amount,
        Null                         fy_15_gift_amount

      From DO_advmnt_actvts adac
      Left Outer Join [salesforce backups].dbo.Account acc
          On adac.AccountID = acc.Id
      Left Outer Join [Analytics\tableau].do_name_key nk
          On nk.do_id = adac.OwnerID

      Where adac.ActivityDate >= '2014-07-01'
        And adac.ActivityDate <= '2018-06-30'
        And (   adac.ActivityType      in ('Visit')
           or (nk.do_team='GULC' and adac.ActivityType in ('Visit', 'Visit Assist'))
           or ( adac.contactor_name        in ('Carma Fauntleroy', 'Katie Mire', 'Becky Pfordresher')
              and ( adac.ActivityType  in ('Visit', 'Visit Assist') --subject line for SubstantiveAction
                     or (adac.ActivityType = 'Prospect Activity' and Subject__c='Substantive Action') or adac.Substantive_Activity = 'true')
              ) --note: revisit CFR criteria for Prospect Activity/Substantive Activity in meeting Feb2018
            )
         /*And  adac.ActivityStatus='Completed' --do we really need this? J.M Answer: Not necessary*/
         /*)Select * from DO_visits --to get quick output window for eye test*/
    ) ,

    DO_asks as  -- logic flow for asks at level --
    ( Select
        oppo.AccountID              as AccountID,
        acc.Name                    as hh_name,
        acc.AQB__District__c        as market,
        nk.do_id                    as do_id,
        Case
          When Month(oppo.ask_date) >= 7 Then Year(oppo.ask_date) + 1
          Else Year(oppo.ask_date)
        End comb_fy,
        Null                        as visit_date,
        Null                        as visit_summ,
        Null                        as visitor,
        oppo.ask_amt                as ask_amt,
        oppo.ask_date               as ask_date,
        oppo.gift_amt               as gift_amt,
        oppo.gift_date              as gift_date,
        nk.first_last               as solicitor,
        oppo.solicitor_level        as solicitor_level,
        oppo.gift_name              as gift_name,
        oppo.gift_unit              as gift_unit,
        'qual_asks'                 as source,
        --all fields below: add'l fields that come after the core 17 fields -- for future ref.
        Null                        as ActivityStatus,
        oppo.StageName              as StageName,
        oppo.lead_solicitor_ID      as lead_solicitor_ID,
        nk.first_last               as first_last,
        nk.last_first               as last_first,
        nk.last_first_comma         as last_first_comma,
        Null                        as contactor,
        Null                        as contactor_name,
        Null                        as Subject__c,
        Null                        as gift_amt_comb_lead_sec,
        Null                         fy_18_gift_amount,
        Null                         fy_17_gift_amount,
        Null                         fy_16_gift_amount,
        Null                         fy_15_gift_amount


      From DO_opportunities oppo
      Left Outer Join [salesforce backups].dbo.Account acc
          On oppo.AccountID = acc.Id
      Left Outer Join [Analytics\tableau].do_name_key nk
          On nk.do_id = oppo.lead_solicitor_ID

      Where  oppo.ask_date >= '2014-07-01' And oppo.ask_date <= '2018-06-30'
         And oppo.solicitor_level = 'Lead Solicitor'
         And Case
                When nk.first_last = 'Mary Palmer'                                         Then 'Y'
                When nk.do_level = 'DA'                                                      Then 'Y'
                When (nk.do_team = 'GUMC Education & Research' Or nk.do_team = 'Lombardi')   Then 'Y'
                When nk.do_team  = 'GULC'       And oppo.ask_amt  >= 50000                   Then 'Y'
                When nk.do_level = 'Leadership' And oppo.ask_amt  >= 500000                  Then 'Y'
                When nk.do_level = 'AVP'        And oppo.ask_amt  >= 500000                  Then 'Y'
                When nk.do_level = 'SDOD'       And oppo.ask_amt  >= 250000                  Then 'Y'
                When nk.do_level = 'DOD'        And oppo.ask_amt  >= 100000                  Then 'Y'
                When nk.do_level = 'ADOD'       And oppo.ask_amt  >= 50000                   Then 'Y'
                Else 'N'
             End = 'Y'
      /*) Select * from DO_visits UNION ALL Select * from DO_asks --to get quick output window for eye test*/
    ) ,

    DO_dollars as  -- logic flow for dollars raised --
    ( Select
        oppo.AccountID              as AccountID,
        acc.Name                    as hh_name,
        acc.AQB__District__c        as market,
        nk.do_id                    as do_id,
        Case
          When Month(oppo.gift_date) >= 7 Then Year(oppo.gift_date) + 1
          Else Year(oppo.gift_date)
        End comb_fy,
        Null                        as visit_date,
        Null                        as visit_summ,
        Null                        as visitor,
        oppo.ask_amt                as ask_amt,
        oppo.ask_date               as ask_date,
        oppo.gift_amt               as gift_amt,
        oppo.gift_date              as gift_date,
        nk.first_last               as solicitor,
        oppo.solicitor_level        as solicitor_level,
        oppo.gift_name              as gift_name,
        oppo.gift_unit              as gift_unit,
        'all_asks'                  as source,
        --all fields below: add'l fields that come after the core 17 fields -- for future ref.
        Null                        as ActivityStatus,
        oppo.StageName              as StageName,
        oppo.lead_solicitor_ID      as lead_solicitor_ID,
        nk.first_last               as first_last,
        nk.last_first               as last_first,
        nk.last_first_comma         as last_first_comma,
        Null                        as contactor,
        Null                        as contactor_name,
        Null                        as Subject__c,
        Null                        as gift_amt_comb_lead_sec,
        oppo.fy18_gift_amount       as fy_18_gift_amount,
        oppo.fy17_gift_amount       as fy_17_gift_amount,
        oppo.fy16_gift_amount       as fy_16_gift_amount,
        oppo.fy15_gift_amount       as fy_15_gift_amount
      /*    --new field below for Dollars YoY Chart boolean - note: need to get distinct dollar_goal_lvl4 from FY15-FY18
        CASE
          --count_all_flags
          When nk.count_all_flag='Y' Then oppo.gift_amt
          --dollar_goal for fy18
                --when greater than or equal to__  AND __ --when less than
          When Sum(oppo.fy18_gift_amount)>= ind.dollar_goal_lvl4 Then oppo.gift_amt
          When Sum(oppo.fy18_gift_amount) < ind.dollar_goal_lvl4 Then oppo.fy18_gift_amount
          --dollar_goal for fy17
                --when greater than or equal to__  AND __ --when less than
          When Sum(oppo.fy17_gift_amount)>= ind.dollar_goal_lvl4_fy17 Then oppo.gift_amt
          When Sum(oppo.fy17_gift_amount) < ind.dollar_goal_lvl4_fy17 Then oppo.fy17_gift_amount
          --dollar_goal for fy16
                --when greater than or equal to__  AND __ --when less than
          When Sum(oppo.fy16_gift_amount)>= ind.dollar_goal_lvl4_fy16 Then oppo.gift_amt
          When Sum(oppo.fy16_gift_amount) < ind.dollar_goal_lvl4_fy16 Then oppo.fy16_gift_amount
          --dollar_goal for fy15
                --when greater than or equal to__  AND __ --when less than
          When Sum(oppo.fy15_gift_amount)>= ind.dollar_goal_lvl4_fy15 Then oppo.gift_amt
          When Sum(oppo.fy15_gift_amount) < ind.dollar_goal_lvl4_fy15 Then oppo.fy15_gift_amount
        END gift_amt_comb_lead_sec*/


      From DO_opportunities oppo
      Left Outer Join [salesforce backups].dbo.Account acc
          On oppo.AccountID = acc.Id
      Left Outer Join [Analytics\tableau].do_name_key nk
          On nk.do_id = oppo.optm_userID
      Left Outer Join [Analytics\tableau].do_goals ind
          On ind.do_id = nk.do_id

      Where /*oppo.StageName in ('Accepted', 'Accepted Stewardship') --use StageName in do_indiv_summ and in tableau Calc fields */
            oppo.solicitor_level in ('Lead Solicitor', 'Secondary Solicitor')
        And (  (ask_date  >= '2014-07-01'  And ask_date  <= '2018-06-30') Or
                 (gift_date >= '2014-07-01'  And gift_date <= '2018-06-30')
            )

      Group by oppo.AccountID, acc.Name,acc.AQB__District__c, nk.do_id, oppo.ask_amt,
               oppo.ask_date, oppo.gift_amt, oppo.gift_date, nk.first_last, oppo.solicitor_level,
               oppo.gift_name, oppo.gift_unit, oppo.StageName, oppo.lead_solicitor_ID, nk.first_last, nk.last_first,
               nk.last_first_comma, ind.dollar_goal_lvl4, ind.dollar_goal_lvl4_fy17, ind.dollar_goal_lvl4_fy16,
               ind.dollar_goal_lvl4_fy15, oppo.fy18_gift_amount, oppo.fy17_gift_amount, oppo.fy16_gift_amount,
               oppo.fy15_gift_amount, nk.count_all_flag
    )

SELECT * From DO_visits
    Union All
SELECT * From DO_asks
    Union All
SELECT * From DO_dollars
GO;
-------






/*-----------------------------------------------------------------  End Code  -----------------------------------------------------------------*/


/***** VI.  Step 6: do_indiv_summ - roll-up of activity list, do_name_key, and do_goals.     *****/

CREATE VIEW [Analytics\tableau].do_indiv_summ AS

  WITH

    fy18_visits As   -- roll up of visits: use self join to roll up 'contactor' visits then get do_id
    ( Select
        al.visitor,
        al.visits,
        dnk.do_id

      From ( --use subquery to roll up all visits then join on visitor=first_last
             Select visitor, count(*) as visits
                From [Salesforce Dev].[Analytics\tableau].activity_list
                  Where source = 'visits'
                   And visit_date >= '2017-07-01' And visit_date <= '2018-06-30'
                   And contactor is not null
             Group by visitor
           ) al
      Left Outer Join (Select do_id, first_last from [Salesforce Dev].[Analytics\tableau].do_name_key) dnk
            On al.visitor = dnk.first_last

      Where dnk.do_id is not null
    /*) Select * from fy18_visits  --to get quick output window for eye test*/
    ) ,

    fy18_asks As   -- roll up of asks
    ( Select
        dnk.do_id,
        al.solicitor,
        al.asks

      From (  --use subquery to roll up asks on solictor then join do_id
              Select solicitor, count(*) as asks
                From [Salesforce Dev].[Analytics\tableau].activity_list
                Where source = 'qual_asks'
                  And ask_date >= '2017-07-01' And ask_date <= '2018-06-30'
                  And solicitor is not null
              Group by solicitor
           ) al

      Left Outer Join (Select do_id, first_last from [Salesforce Dev].[Analytics\tableau].do_name_key) dnk
            On solicitor = dnk.first_last

      Where dnk.do_id is not null


      /*) highlight from Select to end of group by line --to get quick output window for eye test*/
    ) ,

    fy18_dollars As   -- roll up of dollars
    ( Select
        r.do_id,
        r.solicitor,
        r.fy18_1st_solicitor_dollars,
        r.fy18_co_solicitor_dollars,
        r.goal_dollars,
        r.count_all_flag,
        --this final roll-up was necessary to compare "goal_dollars" (aggregated in the last sub-query) to the goals themselves.
        Case
          When r.dollar_goal_single = 0 Then (Case
                                                When r.goal_dollars >= r.dollar_goal_lvl5 Then 'Level 5 Achieved'
                                                When r.goal_dollars >= r.dollar_goal_lvl4 Then 'Level 4 Achieved'
                                                When r.goal_dollars >= r.dollar_goal_lvl3 Then 'Level 3 Achieved'
                                                Else Null
                                              End)
          Else (Case
                  When r.goal_dollars >= r.dollar_goal_single Then 'Goal Achieved'
                  Else Null
                End
               )
        End goal_achieved

        From
          (Select d.do_id, d.solicitor, d.fy18_1st_solicitor_dollars, d.fy18_co_solicitor_dollars,
                  d.dollar_goal_single, d.dollar_goal_lvl3, d.dollar_goal_lvl4, d.dollar_goal_lvl5,d.count_all_flag,

                 --This aggregation gives us a dollar total to be compared to the goals, taking team counting rules into account.
                 Case
                    When d.count_all_flag = 'Y'
                        Then (d.fy18_1st_solicitor_dollars + d.fy18_co_solicitor_dollars)
                    When (min(d.fy18_1st_solicitor_dollars) >= min(d.dollar_goal_lvl4))
                        Then (d.fy18_1st_solicitor_dollars + d.fy18_co_solicitor_dollars)
                    Else d.fy18_1st_solicitor_dollars
                 End goal_dollars

                 From
                   (Select k.do_id,
                           p.solicitor,
                           --these two case statements total two different sums: (1) 1st Solicitor $ Closed; (2) Co-Solicitor $ Closed.
                           Sum(Case When p.solicitor_level  = 'Lead Solicitor'  Then p.gift_amt Else 0 End) fy18_1st_solicitor_dollars,
                           Sum(Case When p.solicitor_level  = 'Secondary Solicitor'  Then p.gift_amt Else 0 End) fy18_co_solicitor_dollars,
                           /*This case statement flags whether the DO's team counts all dollars or only counts co-solicitor
                             dollars under certain conditions.*/
                           Case When (k.do_team = 'GUMC Education & Research' Or k.do_team = 'Lombardi' Or k.do_team = 'GULC'
                                          Or k.do_team = 'Planned Giving' Or k.do_team = 'Corporate & Foundation Relations')
                                    Then 'Y'
                           End count_all_flag,
                           --we also carry over all of the goal and team information to be used in the next sub-query.
                           g.dollar_goal_lvl3, g.dollar_goal_lvl4, g.dollar_goal_lvl5, g.dollar_goal_single,
                           k.do_team, k.do_level

                            --joins to DO tables to check team (because diff teams count this metric diff) and goals.
                            From [Salesforce Dev].[Analytics\tableau].activity_list p
                            Left Outer Join [Salesforce Dev].[Analytics\tableau].do_name_key k
                                     On p.solicitor = k.first_last
                            Left Outer Join [Salesforce Dev].[Analytics\tableau].do_goals g
                                     On g.do_id = k.do_id

                            --change FY dates here
                            Where p.gift_date >= '2017-07-01'
                                And p.gift_date <= '2018-06-30'
                                And p.source = 'all_asks'
                                And p.StageName in ('Accepted','Accepted - Stewardship')
                                And k.do_id is not null

                            --group by allows us to pass these fields on to the next sub-query
                            Group by p.solicitor, g.dollar_goal_lvl3, g.dollar_goal_lvl4, g.dollar_goal_lvl5,
                                     g.dollar_goal_single, k.do_team, k.do_level, k.do_id
                            --having keeps only DOs with FY17 data, so we don't have to call them in the other sub-queries.
                            HAVING SUM(p.gift_amt) > 0) as d

          --GROUP BY allows us to pass these fields on to the final roll-up sub-query
          GROUP BY d.do_id, d.solicitor, d.fy18_1st_solicitor_dollars,
                   d.fy18_co_solicitor_dollars, d.count_all_flag, d.dollar_goal_single,
                   d.dollar_goal_lvl3, d.dollar_goal_lvl4, d.dollar_goal_lvl5) as r
          /* highlight from Select to end of group by line --to get quick output window for eye test*/
    ) ,

    fy18_goals As -- roll up of goals
    ( Select
        g.do_id, g.goal_date,  g.visit_goal_lvl3,  g.visit_goal_lvl4,  g.visit_goal_lvl5, g.visit_goal_single,
        g.ask_goal_lvl3,  g.ask_goal_lvl4,  g.ask_goal_lvl5, g.ask_goal_single, g.dollar_goal_lvl3,
        g.dollar_goal_lvl4, g.dollar_goal_lvl5, g.dollar_goal_single,
        Case
          When g.visit_goal_single is Null Then visit_goal_lvl3
          Else g.visit_goal_single
        End visit_goal,
        Case
          When g.ask_goal_single is Null Then ask_goal_lvl3
          Else g.ask_goal_single
        End ask_goal,
        Case
          When g.dollar_goal_single is Null Then dollar_goal_lvl3
          Else g.dollar_goal_single
        End dollar_goal

        From [Salesforce Dev].[Analytics\tableau].do_goals g
    /* highlight from Select to end of group by line --to get quick output window for eye test*/
    /* highlight from Select to end of group by line --to get quick output window for eye test*/
    )

SELECT vis.do_id, k.last_first_comma, k.last_first, k.do_team, k.do_level, gol.goal_date,
       vis.visits fy18_visits, ask.asks fy18_asks, dol.goal_dollars,
       gol.visit_goal_lvl3, gol.visit_goal_lvl4, gol.visit_goal_lvl5, gol.visit_goal_single, gol.ask_goal_lvl3,
       gol.ask_goal_lvl4, gol.ask_goal_lvl5, gol.ask_goal_single, gol.dollar_goal_lvl3, gol.dollar_goal_lvl4,
       gol.dollar_goal_lvl5, gol.dollar_goal_single,
       dol.fy18_1st_solicitor_dollars, dol.fy18_co_solicitor_dollars,
       Case --if dollar lvl 4 reached then total fy18 dollars is lead+secondary for central team
          When k.count_all_flag ='Y'  Then fy18_1st_solicitor_dollars+fy18_co_solicitor_dollars
          When sum((fy18_1st_solicitor_dollars+fy18_co_solicitor_dollars))>=dollar_goal_lvl4 Then fy18_1st_solicitor_dollars+fy18_co_solicitor_dollars
          When sum((fy18_1st_solicitor_dollars+fy18_co_solicitor_dollars))<dollar_goal_lvl4 Then  fy18_1st_solicitor_dollars
          When dollar_goal_lvl4 is Null Then fy18_1st_solicitor_dollars
          End comb_fy18_doll

  From fy18_visits vis
  Left Join fy18_asks ask
      On ask.do_id = vis.do_id
  Left Join fy18_dollars dol
      On dol.do_id = vis.do_id
  Left Join fy18_goals gol
      On gol.do_id = vis.do_id
  Left Join [Salesforce Dev].[Analytics\tableau].do_name_key k
      On k.do_id = vis.do_id

  Where vis.do_id is not null

  Group by vis.do_id, k.last_first_comma, k.last_first, k.do_team, k.do_level, gol.goal_date, vis.visits, ask.asks,
           dol.goal_dollars, gol.visit_goal_lvl3, gol.visit_goal_lvl4, gol.visit_goal_lvl5,
           gol.visit_goal_single, gol.ask_goal_lvl3, gol.ask_goal_lvl4, gol.ask_goal_lvl5,
           gol.ask_goal_single, gol.dollar_goal_lvl3, gol.dollar_goal_lvl4, gol.dollar_goal_lvl5,
           gol.dollar_goal_single, dol.fy18_1st_solicitor_dollars, dol.fy18_co_solicitor_dollars, k.count_all_flag
GO;
-------

/*-----------------------------------------------------------------  End Code  -----------------------------------------------------------------*/

/***** VII.  Step 7: Create fy18_top30   *****/

CREATE VIEW [Analytics\tableau].fy18_top30 AS

  WITH

    top_gifts As   -- roll up of top 30 gifts of Accepted & Accepted Stewardship Opportunities on Account Level
    ( Select Top 32
        act.Id                                as AccountID,
        act.Name                              as hh_name,
        sum(opp.Amount)                       as gift_amt,
        max(opp.CloseDate)                    as gift_date,
        count(distinct opp.Lead_Solicitor__c) as total_sols,
        --all fields below: add'l fields for future ref
        opp.Id                                as opportunity_ID

      From [salesforce backups].dbo.Account act
      Left Outer Join [salesforce backups].dbo.Opportunity opp
          On opp.AccountId = act.Id

      Where opp.StageName in ('Accepted', 'Accepted - Stewardship')
        And opp.CloseDate >= '2017-07-01' And opp.CloseDate <= '2018-06-30'
         --caution: below hardwire exclude until further notice; quick check in weekly
        And opp.Id not in ('0063600000TVS9tAAH', '0063600000TVSCoAAP') --Meyer opportunities (duplicates) hardwire until cleaned up

      Group by act.Id, act.name, opp.Id
      Order by Sum(opp.Amount) desc, max(opp.CloseDate) desc
    /*) Select * from top_gifts  --to get quick output window for eye test*/
    ) ,

    base_sol As   -- roll up of total solicitors
    ( Select Distinct Top 32
        tg.AccountID                         as AccountID,
        tg.hh_name                           as hh_name,
        tg.gift_amt                          as gift_amt,
        tg.gift_date                         as gift_date,
        tg.opportunity_ID ,

        Case
            When tg.total_sols>1 Then 'Multiple Lead Solicitors'
            When opp.AccountId = '0013600001Am5G5AAJ' and gift_amt ='450000.00' Then 'Multiple Lead Solicitors' --hardwire, fix later
            When (opp.Lead_Solicitor__c='' OR opp.Lead_Solicitor__c is Null) Then 'No Lead Solicitor Entered'
            Else owner_user.Name
        End solicitor

      From top_gifts tg
      Left Outer Join [salesforce backups].dbo.Opportunity opp
          On tg.AccountID = opp.AccountId
      Left Outer Join [salesforce backups].dbo.[User] owner_user
          On owner_user.Id = opp.Lead_Solicitor__c

      Where opp.StageName in ('Accepted', 'Accepted - Stewardship')
        And opp.CloseDate>= '2017-07-01' And opp.CloseDate <= '2018-06-30'
          --caution: below hardwire exclude until further notice; quick check in weekly
        And opp.Id not in ('0063600000TVS9tAAH', '0063600000TVSCoAAP') --Meyer opportunities (duplicates)
    /* highlight from Select to end of group by line --to get quick output window for eye test*/

      Order by tg.gift_amt desc, tg.gift_date desc
    )
    /*base_and_er_br_collab*/
SELECT  AccountID, hh_name, sum(gift_amt) as gift_amt, gift_date, solicitor
  From base_sol sol1
  Group by AccountID, hh_name, gift_amt, gift_date, solicitor

GO;

-------

/*-----------------------------------------------------------------  End Code  -----------------------------------------------------------------*/

/***** IV.  Step 8: comb_hh_gusy     *****/
CREATE VIEW [Analytics\tableau].comb_hh_gusy AS

  WITH
          --get rn1 when AQB_IsPrimaryContact = 'Yes', and rn2 when 'No'
      contacts_gusy As
      ( Select Id, AccountId, Gambit_GUSY__c, AQB__IsPrimaryContact__c,
               row_number() over (partition by c.AccountId ORDER BY c.AQB__IsPrimaryContact__c DESC) rn
          From [salesforce backups].dbo.Contact c
      ) ,
           -- get hierarchy of Gusy for primary contact, then primary + non-primary if available
      contacts_comb_gusy  As
      ( Select acct.Id as AccountID,
               Case
                  When c.Gambit_GUSY__c is Null And c2.Gambit_GUSY__c is null Then Null
                  When c.Gambit_GUSY__c is null And c2.Gambit_GUSY__c is not null Then rtrim(c2.Gambit_GUSY__c)
                  When c.Gambit_GUSY__c is not Null And c2.Gambit_GUSY__c is null Then rtrim(c.Gambit_GUSY__c)
                Else
                  (Case
                      When c.AccountId  =  c2.AccountId  Then rtrim(c.Gambit_GUSY__c) + ' & ' + rtrim(c2.Gambit_GUSY__c)
                      When c.AccountId !=  c2.AccountId  Then rtrim(c.Gambit_GUSY__c)
                  END)
               End comb_gusy
          From [salesforce backups].dbo.Account acct
          Left outer join contacts_gusy c
              On c.AccountId=acct.Id And c.rn=1 --recall rn as 1 for primary contact
          Left outer join contacts_gusy c2
              On c2.AccountId=acct.Id and c2.rn=2 --recall rn as 2 when contact is not primary

          Where c.Gambit_GUSY__c is not null --condition carried over from PRM's analgous view's structure
      )
    --only want distinct accounts for comb_gusy available
SELECT *
  From contacts_comb_gusy
  /*Where AccountID='0013600001AJI85AAH'*/ --david lizza test
GO;


-------
/*-----------------------------------------------------------------  End Code  -----------------------------------------------------------------*/



/*****    Appendix.  A:  Other Qrys  (In Case of Reference) & Testing -- Distinct Counts & Some Grouping   *****/

    -- A.1: Query using Task Object [note that Task is an old object that isn't useful now]
CREATE VIEW [Analytics\tableau].DO_Dashboards_Task AS
  WITH Tasks_DO AS
  ( Select
      t.Id,
      t.AccountId,
      t.ActivityDate,
      t.CreatedById, cbi_user.Name   CreatedByName, t.CreatedDate,
      t.LastModifiedById, lmi_user.Name   LastModifiedByName, t.LastModifiedDate,
      t.OwnerId, owner_user.Name OwnerName,
      t.Gambit_Key__c, t.External_Id__c,
      t.RecordTypeId, rt.Name         recordType,
      t.Type, t.TaskSubtype,
      t.SystemModstamp,
      t.WhatId,
      t.WhoId

     FROM [salesforce backups].dbo.Task t -- where t.Id = '00T3600002Xv3K0EAJ'


    Left Outer Join [salesforce backups].dbo.[User] cbi_user    -- get all user IDs for creators
      ON cbi_user.Id = t.CreatedById
    Left Outer Join [salesforce backups].dbo.[User] lmi_user    -- get all user IDs for last modified
      ON lmi_user.Id = t.LastModifiedById
    Left Outer Join [salesforce backups].dbo.[User] owner_user  -- get all user IDs for last Owner
      ON owner_user.Id = t.OwnerId
    Left Outer Join [salesforce backups].dbo.RecordType rt      -- get all user IDs for last Owner
      ON rt.Id = t.RecordTypeId
  )

SELECT *
  From Tasks_DO
GO;

------------- END A.1-------------

  -- A.2 Comprehensive AdvancementActivities view
CREATE VIEW [Analytics\blake].DO_Dashboards_AdvActivities AS

  WITH activities_DO AS
  (
    Select
      act.OwnerId                 as OwnerID,         --note: check against OwnerId__c(?)
      owner_user.Name             as OwnerName,
      act.Type__c                 as ActivityType,
      act.Status__c               as ActivityStatus,
      act.Description__c          as Activity_Description,
      act.Substantive_Activity__c as Substantive_Activity,
      act.ActivityDate__c         as ActivityDate,
      act.SystemModstamp          as SystemModstamp,
      act.RecordTypeId            as RecordTypeID,
      rt. Name                    as RecordyTypeName,
      act.Related_Account__c      as Account_ID,
      act.WhoId__c                as Contact_WhoID,

        --add'l information from this point on below, but not necessary at the moment
      act.CreatedById             as CreatedByID,
      cbi_user.Name               as CreatedByName,
      act.CreatedDate             as CreatedDate,
      act.LastModifiedById        as LastModifiedByID,
      lmi_user.Name               as LastModifiedByName,
      act.LastModifiedDate        as LastModifiedName,
        --not sure if useful at this point but gambit id info below
      act.Gambit_Key__c         as Gambit_Key,
      act.External_Id__c        as External_ID,
      act.OwnerId__c            as Contactor, --just a handful (about 8) with multiple OwnerId__c
      act.Assigned_To_2__c      as Contactor2, --Assinged_To fields useful for future reference
      act.Assigned_To_3__c      as Contactor3


    From [salesforce backups].dbo.Advancement_Activity__c act
    Left Outer Join [salesforce backups].dbo.[User] cbi_user    -- get all user IDs for creators
       ON cbi_user.Id = act.CreatedById
    Left Outer Join [salesforce backups].dbo.[User] lmi_user    -- get all user IDs for last modified
       ON lmi_user.Id = act.LastModifiedById
    Left Outer Join [salesforce backups].dbo.[User] owner_user  -- get all user IDs for last Owner
       ON owner_user.Id = act.OwnerId
    Left Outer Join [salesforce backups].dbo.RecordType rt      -- get all user IDs for last Owner
       ON rt.Id = act.RecordTypeId

    Where owner_user.Name <> 'Carole Hornik'  --exclude because Visit counts way too high (major data prob)
      And Type__c in ('Visit', 'Visit Assist')
  )

SELECT *
  From activities_DO
GO;

   --another old advancement_activities qry without Related Contacts
WITH DO_advmnt_actvts AS   -- key data fields for advancement activities
    ( Select
        adv.OwnerId                 as OwnerID, --note: check against OwnerId__c(?)
        owner_user.Name             as OwnerName,
        adv.Type__c                 as ActivityType,
        adv.Description__c          as Activity_Description,
        adv.ActivityDate__c         as ActivityDate,
        adv.SystemModstamp          as SystemModstamp,
        adv.Related_Account__c      as AccountID,
        adv.RecordTypeId            as RecordTypeID,
        rt. Name                    as RecordyTypeName,
        adv.Status__c               as ActivityStatus,
        adv.Substantive_Activity__c as Substantive_Activity,
        rc.Advancement_Activity__c  as activity_id_rc,
        rc.Contact__c               as contact_id_rc

      From [salesforce backups].dbo.Advancement_Activity__c adv
      Left Outer Join [salesforce backups].dbo.[User] owner_user -- get all user IDs for Owner
          On owner_user.Id = adv.OwnerId
      Left Outer Join [salesforce backups].dbo.RecordType rt -- get record type name
          On rt.Id = adv.RecordTypeId
      Left Outer Join [salesforce backups].dbo.Advancement_Activity_Related_Contacts__c rc -- get related contacts
        On rc.Advancement_Activity__c = adv.Id


      Where owner_user.Name <> 'Carole Hornik'  --exclude because Visit counts way too high (major data prob)
          And Type__c in ('Visit', 'Visit Assist')
    )
Select * from Do_advmnt_actvts

------------- END A.2-------------

  -- A.3 Comprehensive 'tblProposal' analogous to PRM's
CREATE VIEW [Analytics\blake].tblProposal AS
  (
    Select
      opp.Id                    as OpportunityID,
      opp.StageName             as StageName,
      opp.OwnerId               as OwnerID,
      opp.Lead_Solicitor__c     as Lead_Solicitor_ID,
      opp.AccountId             as AccountID,
      opp.Name                  as Opportunity_name,
      opp.Ask_Date__c           as Ask_Date,
      opp.Ask_Amount__c         as Ask_Amount,
      opp.CloseDate             as Close_Date,
      opp.Amount                as Amount,
      opp.Division__c           as Division,
      opp.AQB__CampaignFund__c  as CampaignFund,
      opp.AQB__Comment__c       as Comment,
      opp.FiscalYear            as Fiscal_Yr,
      opp.FiscalQuarter         as Fiscal_Qtr,
      oppteam.Name              as DO_name,
      oppteam.TeamMemberRole    as TeamMemberRole

    From [salesforce backups].dbo.Opportunity AS opp
    Left Outer Join [salesforce backups].dbo.OpportunityTeamMember AS oppteam
      ON opp.Id = oppteam.OpportunityId
  )
GO;
------------- END A.3-------------


    -- A.4 Comprehensive 'tblProspects' analogous to PRM's (reference -- likely belongs in Appendix sections)
CREATE VIEW [Analytics\blake].tblProspects AS
  (
    Select
      a.Id                        as Account_Id,
      a.Name                      as Account_Name,
      c.Id                        as Contact_Id,
      c.Name                      as Contact_Name,
      a.AQB__AccountExternalID__c as Gambit_Id,
      a.AQB__AccountStatus__c     as Account_Status,
      a.AQB__AccountType__c       as Account_Type,
      a.AQB__District__c          as District,
      a.AQB__Region__c            as Region,
      a.AQB__TotalGifts__c        as Total_Gifts,
      a.Total_Gifts_Count__c      as Total_Gifts_Count,  -- same as a.Total_Gifts__c
      a.BillingCity               as Billing_City,
      a.BillingCountry            as Billing_Country,
      a.BillingState              as Billing_State,
      a.BillingPostalCode         as Billing_Postal_Code,
      a.Capacity_MG_Capacity__c   as GU_Capacity,
      a.Number_of_Contacts__c     as Number_of_Contacts,
      a.Relationship_Manager__c   as Relationship_Manager,
      c.AQB__Age__c               as Age,
      c.AQB__Degree__c            as Degree,
      c.AQB__DegreeYear__c        as Degree_Year,
      c.AQB__School__c            as School,    -- same as c.AQB__PreferredYear__c
      c.AQB__Type__c              as Category,

      -- not sure if we should include c. AQB__SecondaryType__c
      c.Birthdate                 as Birthdate,
      c.Email                     as Contact_Email,
      c.Gambit_GUSY__c            as GUSY,
      c.Gambit_PASY__c            as PASY,
      c.Gender__c                 as Gender,
      c.GU_Affiliations__c        as Affilication,
      c.GU_PrimaryAffiliation__c  as Primary_Affiliation,
      c.Religion__c               as Religion

    From [salesforce backups].dbo.Contact             c
    Left Outer Join [salesforce backups].dbo.Account  a
        On a.Id = c.AccountId
  )
GO;
------------- END A.4-------------

  --A.5 do_goals (put in Appendix)
    --first: csv file data imported directly to schema (data called do_goals_csv_import
    --then: type casting and join to get DO IDs; cast first to a var then any other
WITH
    do_goal_import as
    ( Select 	cast(cast(dg.last_first as varchar) as nvarchar(255))          as last_first,
		          cast(cast(dg.dollar_goal_lvl3 as varchar) as float )           as dollar_goal_lvl3,
              cast(cast(dg.dollar_goal_lvl4 as varchar) as float )           as dollar_goal_lvl4,
              cast(cast(dg.dollar_goal_lvl5 as varchar) as float )           as dollar_goal_lvl5,
              cast(cast(dg.dollar_goal_single as varchar) as nvarchar(255))  as dollar_goal_single,
              cast(cast(dg.visit_goal_lvl3 as varchar) as float )            as visit_goal_lvl3,
              cast(cast(dg.visit_goal_lvl4 as varchar) as float )            as visit_goal_lvl4,
              cast(cast(dg.visit_goal_lvl5 as varchar) as float )            as visit_goal_lvl5,
              cast(cast(dg.visit_goal_single as varchar) as nvarchar(255))   as visit_goal_single,
              cast(cast(dg.ask_goal_lvl3 as varchar) as float )              as ask_goal_lvl3,
              cast(cast(dg.ask_goal_lvl4 as varchar) as float )              as ask_goal_lvl4,
              cast(cast(dg.ask_goal_lvl5 as varchar) as float )              as ask_goal_lvl5,
              cast(cast(dg.ask_goal_single as varchar) as nvarchar(255))     as ask_goal_single,
              cast(cast(dg.goal_date as varchar) as date)                    as goal_date,
              cast(cast(dg.goal_fy as varchar) as int)                       as goal_fy,
              cast(cast(dg.discovery_visit_goal as varchar) as int)          as discovery_visit_goal,
              cast(cast(dg.dollar_goal__lvl4_fy17 as varchar) as float )     as dollar_goal_lvl4_fy17,
              cast(cast(dg.dollar_goal__lvl4_fy16 as varchar) as float )     as dollar_goal_lvl4_fy16,
              cast(cast(dg.dollar_goal__lvl4_fy15 as varchar) as float )     as dollar_goal_lvl4_fy15

      From [Salesforce Dev].[Analytics\blake].do_goals_csv_import dg
    ) ,

    do_namekey as
    ( Select cast(cast(dk.do_id as varchar) as nvarchar(255)) as do_id,
             cast(cast(dk.last_first_comma as varchar) as nvarchar(255)) as last_first_comma,
             cast(cast(dk.last_first as varchar) as nvarchar(255)) as last_first,
             cast(cast(dk.first_last as varchar) as nvarchar(255)) as first_last
      From [Salesforce Dev].[Analytics\tableau].do_name_key dk
    )

SELECT don.do_id,
       don.first_last,
       dgi.*,
       don.last_first_comma
Into [Salesforce Dev].[Analytics\tableau].do_goals
  From do_goal_import dgi
  Left Join do_namekey don    --note: as stated (and tested in Appendix) no Jonathan Rice
      On dgi.last_first = don.last_first_comma
GO;
------------- END A.5-------------

  -- A.6 Old fy18_top30 (as of Feb 16, 2018)
CREATE VIEW [Analytics\tableau].fy18_top30 AS
  WITH top_gifts As   -- roll up of top 30 gifts of Accepted & Accepted Stewardship Opportunities on Account Level
    ( Select Top 30
        act.Id                                as AccountID,
        act.Name                              as hh_name,
        sum(opp.Amount)                       as gift_amt,
        max(opp.CloseDate)                    as gift_date,
        count(distinct opp.Lead_Solicitor__c) as total_sols,
        --all fields below: add'l fields for future ref
        opp.Id                                as opportunity_ID

      From [salesforce backups].dbo.Account act
      Left Outer Join [salesforce backups].dbo.Opportunity opp
          On opp.AccountId = act.Id

      Where opp.StageName in ('Accepted', 'Accepted - Stewardship')
        And opp.CloseDate >= '2017-07-01' And opp.CloseDate <= '2018-06-30'

      Group by act.Id, act.name, opp.Id
      Order by Sum(opp.Amount) desc, max(opp.CloseDate) desc
    /*) Select * from top_gifts  --to get quick output window for eye test*/
    ) ,

    solicitors As   -- roll up of total solicitors
    ( Select
        act.Id                                as AccountID,
        owner_user.Name                       as propsolnam
        --all fields below: add'l fields for future ref

      From [salesforce backups].dbo.Account act
      Left Outer Join [salesforce backups].dbo.Opportunity opp
          On opp.AccountId = act.Id
      Left Outer Join [salesforce backups].dbo.[User] owner_user
          On owner_user.Id = opp.Lead_Solicitor__c

      Where opp.StageName in ('Accepted', 'Accepted - Stewardship')
        And opp.CloseDate>= '2017-07-01' And opp.CloseDate <= '2018-06-30'
        And optm.TeamMemberRole = 'Lead Solicitor'
    /* highlight from Select to end of group by line --to get quick output window for eye test*/
    )

SELECT DISTINCT
    tog.AccountID,
    tog.hh_name,
    tog.gift_amt,
    tog.gift_date,
     Case
        When tog.total_sols >1 Then 'Multiple Lead Solicitors'
        When (sol.propsolnam = '' Or sol.propsolnam is Null) Then 'No Lead Solicitor Entered'
        Else sol.propsolnam
     End solicitor,
    tog.opportunity_ID

  From top_gifts tog
  Left Outer Join solicitors sol
    On sol.AccountID = tog.AccountID
GO;
------------- END A.6-------------


-- A.7: Testing: Distinct Counts and Some Grouping

Select distinct Substantive_Activity from [Salesforce Dev].[Analytics\blake].DO_Dashboards_AdvActivities Go;
Select * from [salesforce backups].dbo.Advancement_Activity__c Go;
Select AQB__ContactExternalID__c from [salesforce backups].dbo.Contact Go;
Select * from [Salesforce Dev].[Analytics\tableau].do_name_key where first_last like '%Carma%' Go;
Select * from [Salesforce Dev].[Analytics\blake].DO_Dashboards_AdvActivities where ActivityType='Visit' Go;
Select distinct ActivityType from [Salesforce Dev].[Analytics\blake].DO_Dashboards_AdvActivities Go; -- result: 'Visit' & 'Visit Assist'
Select distinct do_team from [Salesforce Dev].[Analytics\tableau].do_name_key Go;
-------section break---------

  /*activity type and Status*/
Select distinct Status__c from [salesforce backups].dbo.Advancement_Activity__c Go;
      --some testing on status grouping
Select distinct Status__c, count(*)
  from [salesforce backups].dbo.Advancement_Activity__c where Type__c in ('Visit', 'Visit Assist')
  group by Status__c
Go; --for all Visit or Visit Assists activity types: either completed (44047), in progress(9), not started(1)
-------section break---------

  /*more testing on status grouping*/
Select distinct Status__c, ActivityDate__c, count(*)
  from [salesforce backups].dbo.Advancement_Activity__c
  where Status__c is null /*and Type__c in ('Visit', 'Visit Assist')*/
  group by Status__c, ActivityDate__c
Go;  --result: 2 activities with null Status; none are null for Visit or Visit Assist
-------section break---------

  /*cheeck for three names (line 28 OR subclause in PRM's activity_list*/
Select distinct OwnerName, ActivityType, count(*)
  from [Salesforce Dev].[Analytics\blake].DO_Dashboards_AdvActivities where OwnerName like '%Carma%'
group by OwnerName,ActivityType
Go;
  /*con't: substantive action*/
Select distinct ActivityType from [Salesforce Dev].[Analytics\blake].DO_Dashboards_AdvActivities
  where OwnerName in ('Carma Fauntleroy', 'Katie Mire', 'Becky Pfordresher') /*and Substantive_Activity = 'true'*/

--OwnerID__c is 'Contactor', Assigned_To_2__c and Assigned_To_3__c are Contactor 2 and Contactor 3, respectively
Select  adv1.OwnerId as owner_id_1, adv1.OwnerId__c as ownerID_c1, us.Name as name2
  from [salesforce backups].dbo.Advancement_Activity__c adv1
  left outer join [salesforce backups].dbo.[User] us
      On adv1.OwnerId = us.Id
  where adv1.OwnerId <> adv1.OwnerId__c
Go; --note: results give only 8 for now but this will be useful for the future.
-------section break---------

select distinct TeamMemberRole from [salesforce backups].dbo.OpportunityTeamMember
select distinct AQB__AccountStatus__c from [salesforce backups].dbo.Account
  --how many multiple lead solicitors on the same opportunity
select Id, Lead_Solicitor__c opportunityID, count(*) as count_lead_sol
  from [salesforce backups].dbo.Opportunity group by id, Lead_Solicitor__c
  having count(Lead_Solicitor__c)>1
go; --result is zero, as expected
-------section break---------

  --issue on lead Solicitor distinct names
select distinct opt.name, opp.Lead_Solicitor__c
  from [salesforce backups].dbo.Opportunity opp
  left join [salesforce backups].dbo.OpportunityTeamMember opt
    on opp.id=opt.OpportunityId
  where opp.Lead_Solicitor__c in (select do_id from [Salesforce Dev].[Analytics\tableau].do_name_key)
go;

SELECT OpportunityId, opt.Name, COUNT(DISTINCT UserId)
FROM [salesforce backups].dbo.OpportunityTeamMember opt
WHERE TeamMemberRole = 'Lead Solicitor'
GROUP BY OpportunityId, opt.Name
HAVING COUNT(DISTINCT UserId) > 1
ORDER BY COUNT(*) DESC
GO;

  -- (same issue but concise)
SELECT opt.OpportunityId, opt.Name, opp.Name
FROM [salesforce backups].dbo.Opportunity opp
LEFT JOIN [salesforce backups].dbo.OpportunityTeamMember opt on opp.id = opt.OpportunityId
WHERE opt.UserId != opp.Lead_Solicitor__c AND opt.TeamMemberRole = 'Lead Solicitor'
-------section break---------

  --check lead solicitor id vs do_id from do_name_key
select distinct opt.Name, opp.Lead_Solicitor__c, dk.do_id
  from [Salesforce Dev].[Analytics\tableau].do_name_key dk
  left join [salesforce backups].dbo.Opportunity opp
      on dk.do_id=opp.Lead_Solicitor__c
  left join [salesforce backups].dbo.OpportunityTeamMember opt
      on opt.OpportunityId=opp.Id
  where opt.TeamMemberRole= 'Lead Solicitor'
go;
-------section break---------

--quick query to verify lead solicitor dollars raided in FY18
SELECT u.Name, SUM(Amount) lead_sol_dollars
  From [salesforce backups].dbo.Opportunity o
  Left Join [salesforce backups].dbo.[User] u
      On o.Lead_Solicitor__c = u.Id
  Where CloseDate >= '2017-07-01'
    And CloseDate <= '2018-06-30'
    And StageName in ('Accepted','Accepted - Stewardship', 'Closed without Visit', 'Disqualified')
    And u.Name like '%Meghan Conaton%'
  Group by u.Name
GO;

  --Check dollars--
WITH opportunity_source as (
  Select u.Name, SUM(Amount) lead_sol_dollars
    From [salesforce backups].dbo.Opportunity o
    Left Join [salesforce backups].dbo.[User] u
      On o.Lead_Solicitor__c = u.Id
    Where CloseDate >= '2017-07-01' AND CloseDate <= '2018-06-30' AND StageName IN ('Accepted','Accepted - Stewardship')
    Group by u.Name ) ,
    --vs--
activity_list_comp as (
  Select first_last, sum(gift_amt) lead_sol_dollars
    From [Salesforce Dev].[Analytics\tableau].activity_list
    Where gift_date >= '2017-07-01' And gift_date <= '2018-06-30'
      And StageName in ('Accepted','Accepted - Stewardship')
      And solicitor_level = 'Lead Solicitor'
      And source='all_asks'
  Group by first_last )
    --compare--
Select *
  From opportunity_source opps
  Left outer join activity_list_comp actl
      On opps.Name = actl.first_last
GO;

-------section break---------

--quick query to verify lead solicitor dollars raided in FY18
SELECT u.Name, SUM(Amount) lead_sol_dollars
FROM [salesforce backups].dbo.Opportunity o
LEFT JOIN [salesforce backups].dbo.[User] u on o.Lead_Solicitor__c = u.Id
WHERE CloseDate >= '2017-07-01' AND CloseDate <= '2018-06-30' AND StageName IN ('Accepted','Accepted - Stewardship')
GROUP BY u.Name
-------section break---------

--bring in related contacts so visits are counted distinctly if mutlipe contacts in one activity
SELECT
       ActivityType, Activity_Description, ActivityDate, AccountID, ActivityStatus,
       Substantive_Activity, activity_id_rc, contact_id_rc, contactor_number, contactor
  From  (
    Select
       aa.Type__c ActivityType, aa.Description__c Activity_Description, aa.ActivityDate__c ActivityDate,
       aa.Related_Account__c AccountID, aa.Status__c ActivityStatus, aa.Substantive_Activity__c Substantive_Activity,
       rc.Advancement_Activity__c activity_id_rc, rc.Contact__c contact_id_rc, OwnerId__c contactor_1,
       Assigned_To_2__c contactor_2, Assigned_To_3__c contactor_3
     From [salesforce backups].dbo.Advancement_Activity__c aa
     Left Join [salesforce backups].dbo.Advancement_Activity_Related_Contacts__c rc ON aa.Id = rc.Advancement_Activity__c

     Where Type__c in ('Visit', 'Visit Assist')
) subq
UNPIVOT
   (contactor FOR contactor_number IN
      (contactor_1, contactor_2, contactor_3)
   ) unpvt
GO;
-------section break---------

  --ask amt is 0 or null but opportunity accepted or accepted stewardship
select ask_date, ask_amt, gift_date, gift_amt, solicitor
  from [Salesforce Dev].[Analytics\tableau].activity_list
      where StageName in ('Accepted', 'Accepted - Stewardship')
  order by ask_amt
go;
-------section break---------

  --To be quickly checked in Opportunity object then send for data cleanup
    --1,why do we have any results below, this is a data issue. we shouldn't have any observations --
    --why do we have any results below, this is a data issue. we shouldn't have any observations --
select * from [Analytics\tableau].activity_list where StageName like '%Accepted%' and gift_amt<1 and source = 'all_asks'
go;
  --Opportunities like '%Accepted%' and 0 gift amount check
Select Id as OpportunityID, AccountId, Name Ask_Date__c, Ask_Amount__c, CloseDate, Amount, StageName
  From [salesforce backups].dbo.Opportunity
  Where StageName like '%Accepted%'
    And Amount<1
Go;
    --similarly we shouldn't have any observations here --
select * from [Analytics\tableau].activity_list where ask_amt>=1 and ask_date>=getdate() and source='all_asks'
    -- Opportunity ask date> today and Stage
Select Id as OpportunityID, AccountId, Ask_Date__c, Ask_Amount__c, CloseDate, Amount, StageName
  From [salesforce backups].dbo.Opportunity
  Where  Ask_Amount__c>=1
    And Ask_Date__c>getdate()
Go;
    --what is this $2?
select * from [Analytics\tableau].activity_list where source='all_asks' and AccountID='0013600001AJaRZAA1'
    -- what is this $2?
Select Id as OpportunityID, AccountId, Ask_Date__c, Ask_Amount__c, CloseDate, Amount, StageName
  From [salesforce backups].dbo.Opportunity
  Where AccountId='0013600001AJaRZAA1'
Go;

    ---what is this ask_date null, ask_amt $0 but in Cultivation?
select * from [Analytics\tableau].activity_list where source='all_asks' and AccountID='0013600001AJFYqAAP'
    ---what is this ask_date null, ask_amt $0, Close date <today, but in Cultivation?
Select Id as OpportunityID, AccountId, Ask_Date__c, Ask_Amount__c, CloseDate, Amount, StageName
  From [salesforce backups].dbo.Opportunity
  Where AccountId = '0013600001AJFYqAAP'
GO;

-------section break---------

--Data Issues to be passed along to Maggie/Ashley {update: send on Feb 27, 2018 "Data Issues w/Opportunities.."]

    --table 1: Opportunities with Multiple Lead Solicitors
SELECT OpportunityId, Count(Distinct UserId) as Count_of_Lead_Sol
  From [salesforce backups].dbo.OpportunityTeamMember opt
  Where TeamMemberRole = 'Lead Solicitor'
  Group by OpportunityId
  Having Count(Distinct UserId) > 1
  Order by Count(*) desc
GO;

    --table 2: issues to send to Ashley/Maggie and explanation on lack of two way integration
SELECT opt.OpportunityId, opt.Name, opp.Name, opt.UserId, opp.Lead_Solicitor__c
  From [salesforce backups].dbo.Opportunity opp
  Left Join [salesforce backups].dbo.OpportunityTeamMember opt on opp.id = opt.OpportunityId
  Where opt.UserId != opp.Lead_Solicitor__c
    And opt.TeamMemberRole = 'Lead Solicitor'
GO;
-------section break---------


------------- END A.7-------------

/*-----------------------------------------------------------------  End Appendix A  -----------------------------------------------------------------*/

/*****    Appendix.  B:  All Comments, Notes, and Feedback/Answers Catalogued   *****/

--From Step VI: DO_visits at the end of the Where Clause as of Feb 9, 2018.
             -- And  adac.ActivityStatus='Completed' --do we really need this? J.M Answer: Not necessary
             -- testing result: when activity type is Visit or Visit Assist, 44,047 Completed, 9 In Progress, 1 Not Started
             -- for Substantive_Activity subconditions, note there is only one observation result.
             -- is Substantive_Activity the wrong field to use? or do we not need this for these three individuals?
             -- note: Prospect Activity:
             --PROBLEM:::: 27,251 observations in PRM's activity list but  only ~18,000 in new SF environment(??)

--From DO Name Key: Jonathan Rice is not listed in DO_Management_Teams__c (all three of his user Ids not in that object)
        --select distinct name, Id from [salesforce backups].dbo.[User] where name like '%Jonathan Rice%'
        /*select * from [salesforce backups].dbo.DO_Management__c
            where (User__c='00536000007kjmSAAQ' OR User__c='00536000007kfV1AAI' OR User__c='00536000007kjyXAAQ')
          go; */

--From activity_list: PROBLEM::: (? mb due to testing?) 27,251 observations in PRM's activity_list but  only ~18,000 in new SF environment(??)


--From do_goals (changed import data): when last_first is Dean, Molly changed to Osborn, Molly
                                    -- when Harrigan, Matthew change to Harrigan, Matt
                                    -- when Haskins, Kate change to Smyth Haskins, Katherine
                                    -- when Jones, Mary change to Jones, Mary Kertz
                                    -- when Martini, Rosemarie change to Treanor Martini, Rosemarie
                                    -- when Pagonis, Meg change to Crawford Pagonis, Meg
                                    -- when Rice, Jonathan change to x ; note, no Jonathan Rice in DO_Management, and he has three user Ids
                                    -- when Siebernaler/M change to Siebenaler Bopp, Mindy


/*-----------------------------------------------------------------  End Appendix B  -----------------------------------------------------------------*/

/****************************************************************** END PROJECT FILE ******************************************************************/