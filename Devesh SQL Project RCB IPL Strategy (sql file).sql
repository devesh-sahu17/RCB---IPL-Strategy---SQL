use ipl;

                     -- Objective questions
                     
                     
-- question 1 : List the different dtypes of columns in table “ball_by_ball” 

SELECT column_name, column_type
FROM information_schema.columns
WHERE table_name = 'ball_by_ball';

-- question 2 : What is the total number of runs scored in 1st season by RCB ?

select sum(coalesce(b.Runs_Scored,0)+coalesce(er.Extra_Runs,0)) as runs from ball_by_ball b
join Matches m
on b.Match_Id = m.Match_Id
join team t 
on b.Team_Bowling = t.Team_Id
left join Extra_Runs er
on b.Match_Id = er.Match_Id
and b.over_id = er.over_id
and b.ball_id = er.ball_id
and b.innings_no = er.innings_no
where  m.Season_Id = 6
  AND t.Team_Name = 'Royal Challengers Bangalore';
  
  

    -- question 3 : How many players were more than the age of 25 during season 2014?

select  
    count(distinct p.Player_Id) as Players_Above_25
from Player p
join Player_Match pm 
on p.Player_Id = pm.Player_Id
join Matches m 
on pm.Match_Id = m.Match_Id
join Season s 
on m.Season_Id = s.Season_Id
where s.Season_Year = 2014
and timestampdiff(year, p.DOB, m.Match_Date) > 25;
  
  
  -- question 4 : How many matches did RCB win in 2013? 
  
 select 
    count(*) as rcb_wins_2013
from matches m
join season s 
on m.season_id = s.season_id
join team t 
on m.match_winner = t.team_id
where s.season_year = 2013
and t.team_name = 'Royal Challengers Bangalore';


-- question 5 : List the top 10 players according to their strike rate in the last 4 seasons


with top_10_player as(select
    p.Player_Id,
    p.Player_Name,
    round((sum(b.Runs_Scored) / count(*))*100, 2) as strike_rate
from ball_by_ball b
join Matches m
on b.Match_Id = m.Match_Id
join Season s
on m.Season_Id = s.Season_Id
join Player p
on b.Striker = p.Player_Id
where s.Season_Year>= (
                       select 
					      max(season_year) - 3
					   from season
                       )
group by p.Player_id, p.Player_Name
having count(*) > 0
order by Strike_Rate desc
limit 10
)

select *, 
      dense_rank() over(order by strike_rate desc) as rnk
      from top_10_player;
      
      
 -- question 6 : What are the average runs scored by each batsman considering all the seasons?
 
 
select
    p.player_id,
    p.player_name,
    round(sum(bb.runs_scored) / count(distinct bb.match_id), 2) as average_runs
from player p
join ball_by_ball bb
on p.player_id = bb.striker
group by p.player_id,
		 p.player_name
order by average_runs desc;
 

-- question 7 : What are the average wickets taken by each bowler considering all the seasons?

select
    p.player_id,
    p.player_name,
    round(
        count(w.player_out) / count(distinct b.match_id),
        2
    ) as average_wickets
from ball_by_ball b
join wicket_taken w
on b.match_id = w.match_id
and b.over_id = w.over_id
and b.ball_id = w.ball_id
join out_type ot
on w.kind_out = ot.out_id
join player p
on b.bowler = p.player_id
where ot.out_name not in (
    'run out',
    'retired hurt',
    'obstructing the field'
)
group by p.player_id,
          p.player_name
order by average_wickets desc;


/* Question 8 : 	List all the players who have average runs scored greater than the overall average and who have taken wickets 
                   greater than the overall average */
                   
with player_avg_runs as (
    select
        bb.striker as player_id,
        avg(bb.runs_scored) as avg_runs
    from ball_by_ball bb
    group by bb.striker
),

overall_avg_runs as (
    select
        avg(runs_scored) as overall_avg
    from ball_by_ball
),

player_wickets as (
    select
        b.bowler as player_id,
        count(w.player_out) as wickets
    from ball_by_ball b
    join wicket_taken w
        on b.match_id = w.match_id
       and b.over_id = w.over_id
       and b.ball_id = w.ball_id
    join out_type ot
        on w.kind_out = ot.out_id
    where ot.out_name not in (
        'run out',
        'retired hurt',
        'obstructing the field'
    )
    group by b.bowler
),

overall_avg_wickets as (
    select
        avg(wickets) as overall_avg
    from player_wickets
)

select
    p.player_id,
    p.player_name
from player p
join player_avg_runs par
    on p.player_id = par.player_id
join player_wickets pw
    on p.player_id = pw.player_id
cross join overall_avg_runs oar
cross join overall_avg_wickets oaw
where par.avg_runs > oar.overall_avg
  and pw.wickets > oaw.overall_avg;
  
  
  
  -- Question 9 : 9.	Create a table rcb_record table that shows the wins and losses of RCB in an individual venue.
  
  create table rcb_record as
with rcb_matches as (
    select
        m.match_id,
        m.venue_id,
        m.match_winner,
        t.team_id as rcb_team_id
    from matches m
    join team t
        on t.team_name = 'Royal Challengers Bangalore'
    where t.team_id in (m.team_1, m.team_2)
)
select
    v.venue_id,
    v.venue_name,
    sum(
        case
            when rm.match_winner = rm.rcb_team_id then 1
            else 0
        end
    ) as wins,
    sum(
        case
            when rm.match_winner <> rm.rcb_team_id
                 and rm.match_winner is not null
            then 1
            else 0
        end
    ) as losses
from rcb_matches rm
join venue v
    on rm.venue_id = v.venue_id
group by
    v.venue_id,
    v.venue_name;

select* from rcb_record;


-- Question 10 : What is the impact of bowling style on wickets taken?


with valid_wickets as (
    select
        b.bowler as player_id
    from ball_by_ball b
    join wicket_taken w
        on b.match_id = w.match_id
       and b.over_id = w.over_id
       and b.ball_id = w.ball_id
       and b.innings_no = w.innings_no
    join out_type ot
        on w.kind_out = ot.out_id
    where ot.out_name not in (
        'run out',
        'retired hurt',
        'obstructing the field'
    )
),
bowler_styles as (
    select
        p.player_id,
        bs.bowling_skill
    from player p                                        
    join bowling_style bs
        on p.bowling_skill = bs.bowling_id
),
style_wickets as (
    select
        bs.bowling_skill,
        count(*) as wickets
    from valid_wickets vw
    join bowler_styles bs
        on vw.player_id = bs.player_id
    group by bs.bowling_skill
)
select
    bowling_skill,
    wickets
from style_wickets
order by wickets desc;


/* Question 11 : Write the SQL query to provide a status of whether the performance of the team is better than the previous year's 
                 performance on the basis of the number of runs scored by the team in the season and the number of wickets taken*/
                 
                 
     with team_runs as (
    select
        m.season_id,
        b.team_batting as team_id,
        sum(b.runs_scored) as total_runs
    from ball_by_ball b
    join matches m
	on b.match_id = m.match_id
    group by m.season_id, b.team_batting
),

team_wickets as (
    select
        m.season_id,
        b.team_bowling as team_id,
        count(*) as total_wickets
    from ball_by_ball b
    join wicket_taken w
	on b.match_id = w.match_id
	and b.over_id = w.over_id
	and b.ball_id = w.ball_id
	and b.innings_no = w.innings_no
    join out_type ot
	on w.kind_out = ot.out_id
    join matches m
	on b.match_id = m.match_id
    where ot.out_name not in (
        'run out',
        'retired hurt',
        'obstructing the field'
    )
    group by m.season_id, b.team_bowling
),

team_performance as (
    select
        r.season_id,
        r.team_id,
        r.total_runs,
        w.total_wickets
    from team_runs r
    join team_wickets w
	on r.season_id = w.season_id
	and r.team_id = w.team_id
),

comparison as (
    select
        tp.*,
        lag(tp.total_runs) over (partition by tp.team_id order by tp.season_id) as prev_runs,
        lag(tp.total_wickets) over (partition by tp.team_id order by tp.season_id) as prev_wickets
    from team_performance tp
)
select
    c.team_id,
    c.season_id,
    case
        when c.prev_runs is null then 'no previous season'
        when c.total_runs > c.prev_runs
		and c.total_wickets > c.prev_wickets
		then 'better'
        when c.total_runs < c.prev_runs
		and c.total_wickets < c.prev_wickets
		then 'worse'
        else 'same'
    end as performance_status
from comparison c
where season_id>6
order by c.team_id, c.season_id;


-- Question 12 : Can you derive more KPIs for the team strategy?

 -- 1.total runs per season (rcb)
 
 with rcb_id as (
    select team_id
    from team
    where team_name like '%royal challengers%'
),
rcb_runs as (
    select
        m.season_id,
        sum(b.runs_scored) as total_runs
    from ball_by_ball b
    join matches m
	on b.match_id = m.match_id
    join rcb_id r
	on b.team_batting = r.team_id
    group by m.season_id
)
select *
from rcb_runs
order by season_id;


-- 2. average runs per match

with rcb_id as (
    select team_id
    from team
    where team_name like '%royal challengers%'
),
rcb_stats as (
    select
        m.season_id,
        sum(b.runs_scored) as total_runs,
        count(distinct b.match_id) as matches_played
    from ball_by_ball b
    join matches m
        on b.match_id = m.match_id
    join rcb_id r
        on b.team_batting = r.team_id
    group by m.season_id
)
select
    season_id,
    total_runs / matches_played as avg_runs_per_match
from rcb_stats;


-- 3 powerplay scoring (overs <= 6)

with id as (
    select team_id
    from team
    where team_name like '%royal challengers%'
),
powerplay_runs as (
    select
        m.season_id,
        sum(b.runs_scored) as powerplay_runs
    from ball_by_ball b
    join matches m
        on b.match_id = m.match_id
    join id r
        on b.team_batting = r.team_id
    where b.over_id <= 6
    group by m.season_id
)
select *
from powerplay_runs;


-- 4 dot ball percentage (batting)

with id as (
    select team_id
    from team
    where team_name like '%royal challengers%'
),
batting_balls as (
    select
        m.season_id,
        count(*) as total_balls,
        sum(case when b.runs_scored = 0 then 1 else 0 end) as dot_balls
    from ball_by_ball b
    join matches m
	on b.match_id = m.match_id
    join id r
	on b.team_batting = r.team_id
    group by m.season_id
)
select
    season_id,
    round((dot_balls / total_balls) * 100,2) as dot_ball_percentage_batting
from batting_balls;


-- 5 dot ball percentage (bowling)

with id as (
    select team_id
    from team
    where team_name like '%royal challengers%'
),
bowling_balls as (
    select
        m.season_id,
        count(*) as total_balls,
        sum(case when b.runs_scored = 0 then 1 else 0 end) as dot_balls
    from ball_by_ball b
    join matches m
        on b.match_id = m.match_id
    join id r
        on b.team_bowling = r.team_id
    group by m.season_id
)
select
    season_id,
    round((dot_balls / total_balls) * 100,2) as dot_ball_percentage_bowling
from bowling_balls;


-- 6 home vs away performance

 with id as (
    select team_id
    from team
    where team_name like '%royal challengers%'
),

match_split as (
    select
        m.season_id,
        m.match_id,
        m.match_winner,
        case
            when m.team_1 = r.team_id then 'home'
            when m.team_2 = r.team_id then 'away'
        end as venue_type
    from matches m
    join id r
        on m.team_1 = r.team_id
        or m.team_2 = r.team_id
),

rcb_results as (
    select
        season_id,
        venue_type,
        count(*) as matches_played,
        sum(case when match_winner = (select team_id from id)
                 then 1 else 0 end) as wins
    from match_split
    group by season_id, venue_type
)

select
    season_id,
    venue_type,
    matches_played,
    wins,
    round((wins / matches_played) * 100,2) as win_percentage
from rcb_results
order by season_id, venue_type;


/* Question 13 : Using SQL, write a query to find out the average wickets taken by each bowler in each venue. Also, rank the 
                        gender according to the average value.*/

with valid_wickets as (
    select
        b.bowler as player_id,
        m.venue_id,
        m.match_id
    from ball_by_ball b
    join wicket_taken w
        on b.match_id = w.match_id
       and b.over_id = w.over_id
       and b.ball_id = w.ball_id
       and b.innings_no = w.innings_no
    join out_type ot
        on w.kind_out = ot.out_id
    join matches m
        on b.match_id = m.match_id
    where ot.out_name not in (
        'run out',
        'retired hurt',
        'obstructing the field'
    )
),

bowler_match_wickets as (
    select
        player_id,
        venue_id,
        match_id,
        count(*) as wickets_in_match
    from valid_wickets
    group by player_id, venue_id, match_id
),

bowler_venue_avg as (
    select
        player_id,
        venue_id,
        avg(wickets_in_match) as avg_wickets
    from bowler_match_wickets
    group by player_id, venue_id
)

select
    p.player_name,
    v.venue_name,
    bva.avg_wickets,
    rank() over (
        partition by v.venue_id
        order by bva.avg_wickets desc
    ) as venue_rank
from bowler_venue_avg bva
join player p
    on bva.player_id = p.player_id
join venue v
    on bva.venue_id = v.venue_id
order by v.venue_name, venue_rank;




-- Question 14 : Which of the given players have consistently performed well in past seasons?

#for batting:

with batting_performace as (
select
Striker,
Player_Name,
sum(runs_scored) as total_runs,
count(distinct Match_Id) as Innings_played,
round(sum(runs_scored)/count(distinct Match_Id), 2) as average_runs
from ball_by_ball b
join player p
on b.striker = p.Player_Id
group by striker
)

select * from batting_performace

WHERE total_runs > 1500 AND Innings_played > 40;


# for bowling:

with bowler as (
    select
        b.bowler as bowler_id,
        p.player_name,
        count(w.player_out) as total_wickets,
        count(distinct b.match_id) as innings_played,
        round(
            count(w.player_out) / count(distinct b.match_id),
            2
        ) as avg_wickets_taken
    from ball_by_ball b
    join player p
        on b.bowler = p.player_id
    join wicket_taken w
        on b.match_id = w.match_id
       and b.over_id = w.over_id
       and b.ball_id = w.ball_id
       and b.innings_no = w.innings_no
    join matches m
        on b.match_id = m.match_id
    group by
        b.bowler,
        p.player_name
)

select *
from bowler
where total_wickets > 50
  and innings_played > 30
order by total_wickets desc, innings_played desc;


-- Question 15: Are there players whose performance is more suited to specific venues or conditions?

# for batsman:
with batting_venue as (
    select
        p.player_id,
        p.player_name,
        m.venue_id,
        v.venue_name,
        b.match_id,
        sum(b.runs_scored) as runs_in_match
    from ball_by_ball b
    join matches m
        on b.match_id = m.match_id
    join venue v
        on m.venue_id = v.venue_id
    join player p
        on b.striker = p.player_id
    group by p.player_id, p.player_name, m.venue_id, v.venue_name, b.match_id
),

player_venue_avg as (
    select
        bv.player_id,
        bv.player_name,
        bv.venue_id,
        bv.venue_name,
        sum(bv.runs_in_match) / count(distinct bv.match_id) as avg_runs_per_match_venue
    from batting_venue bv
    group by bv.player_id, bv.player_name, bv.venue_id, bv.venue_name
),

player_overall_avg as (
    select
        p.player_id,
        p.player_name,
        sum(b.runs_scored) / count(distinct b.match_id) as overall_avg_runs
    from ball_by_ball b
    join player p
        on b.striker = p.player_id
    group by p.player_id, p.player_name
),

player_best_venue as (
    select
        pva.player_id,
        pva.player_name,
        pva.venue_name,
        pva.avg_runs_per_match_venue,
        poa.overall_avg_runs,
        row_number() over (
            partition by pva.player_id
            order by pva.avg_runs_per_match_venue desc
        ) as rn
    from player_venue_avg pva
    join player_overall_avg poa
        on pva.player_id = poa.player_id
    where pva.avg_runs_per_match_venue > poa.overall_avg_runs * 1.2
)

select
    player_id,
    player_name,
    venue_name,
    round(avg_runs_per_match_venue,2) as avg_runs_per_match_venue,
    round(overall_avg_runs,2) as overall_avg_runs
from player_best_venue
where rn = 1
order by player_name;


# for bowler:

with valid_wickets as (
    select
        b.bowler as player_id,
        m.venue_id,
        v.venue_name,
        m.match_id
    from ball_by_ball b
    join wicket_taken w
        on b.match_id = w.match_id
       and b.over_id = w.over_id
       and b.ball_id = w.ball_id
       and b.innings_no = w.innings_no
    join out_type ot
        on w.kind_out = ot.out_id
    join matches m
        on b.match_id = m.match_id
    join venue v
        on m.venue_id = v.venue_id
    where ot.out_name not in ('run out','retired hurt','obstructing the field')
),

bowler_match_wickets as (
    select
        player_id,
        venue_id,
        venue_name,
        match_id,
        count(*) as wickets_in_match
    from valid_wickets
    group by player_id, venue_id, venue_name, match_id
),

bowler_venue_avg as (
    select
        player_id,
        venue_id,
        venue_name,
        avg(wickets_in_match) as avg_wickets_per_match_venue
    from bowler_match_wickets
    group by player_id, venue_id, venue_name
),

bowler_overall_avg as (
    select
        player_id,
        avg(wickets_in_match) as overall_avg_wickets
    from bowler_match_wickets
    group by player_id
)

select
    bva.player_id,
    p.player_name,
    bva.venue_name,
    bva.avg_wickets_per_match_venue,
    boa.overall_avg_wickets
from bowler_venue_avg bva
join bowler_overall_avg boa
    on bva.player_id = boa.player_id
join player p
    on bva.player_id = p.player_id
where bva.avg_wickets_per_match_venue > boa.overall_avg_wickets * 1.2  -- 20% better
order by p.player_name, avg_wickets_per_match_venue desc;


                                      -- Subjective Questions
                                      
	
-- Question 1: How does the toss decision affect the result of the match? And is the impact limited to only specific venues?
                                      
-- 1 : Matches won by toss-winning team:

select 
    t.team_name as toss_winner,
    count(*) as total_matches,
    sum(case when m.match_winner = m.toss_winner then 1 else 0 end) as wins_after_toss,
    round(sum(case when m.match_winner = m.toss_winner then 1 else 0 end)/count(*)*100,2) as win_percentage
    
from matches m
join team t on m.toss_winner = t.team_id
group by t.team_name;

-- 2: Venue-Specific Impact 

with venue_toss as (
    select
        m.venue_id,
        v.venue_name,
        m.toss_winner,
        m.match_winner
    from matches m
    join venue v on m.venue_id = v.venue_id
)
select
    venue_name,
    count(*) as total_matches,
    sum(case when toss_winner = match_winner then 1 else 0 end) as toss_win_matches,
    round(sum(case when toss_winner = match_winner then 1 else 0 end)/count(*)*100,2) as toss_win_percent
from venue_toss
group by venue_name
order by toss_win_percent desc;


-- Question 2: Suggest some of the players who would be best fit for the team.

-- a) Consistent Batting Performers

with batting_consistency as (
    select
    p.player_id,
    p.player_name,
    round(sum(b.runs_scored) / count(distinct b.match_id), 2) as avg_runs,
	round(stddev(b.runs_scored),2) as variation
from player p
join ball_by_ball b
on p.player_id = b.striker
group by p.player_id,
		 p.player_name
order by avg_runs desc
 
)
select *
from batting_consistency
where avg_runs > 25 and variation < 15
order by avg_runs desc;


-- b)Consistent Bowling Performers


with valid_wickets as (
    select
        w.match_id,
        w.innings_no,
        w.player_out,
        b.bowler
    from wicket_taken w
    join out_type ot
        on w.kind_out = ot.out_id
    join ball_by_ball b
        on w.match_id = b.match_id
       and w.over_id = b.over_id
       and w.ball_id = b.ball_id
       and w.innings_no = b.innings_no
    where ot.out_name not in ('run out', 'retired hurt', 'obstructing the field')
),

bowler_match_wickets as (
    select
        bowler as player_id,
        match_id,
        count(*) as wickets_in_match
    from valid_wickets
    group by bowler, match_id
),

bowler_avg as (
    select
        player_id,
        round(avg(wickets_in_match),2) as avg_wickets_per_match
    from bowler_match_wickets
    group by player_id
)

select
    b.player_id,
    p.player_name,
    b.avg_wickets_per_match as avg_wickets_per_match
from bowler_avg b
join player p
    on b.player_id = p.player_id
    where b.avg_wickets_per_match >=2
order by avg_wickets_per_match desc;

-- Question 3: What are some of the parameters that should be focused on while selecting the players?

-- (a) batting average per player

select
    p.player_id,
    p.player_name,
    sum(b.runs_scored) as total_runs,
    count(distinct b.match_id) as matches_played,
    round(sum(b.runs_scored) / count(distinct b.match_id),2) as avg_runs_per_match
from ball_by_ball b
join player p
    on b.striker = p.player_id
group by p.player_id, p.player_name
having matches_played >= 10
order by avg_runs_per_match desc;


-- (B) wickets per match:

with valid_wickets as (
    select
        b.bowler as player_id,
        b.match_id
    from ball_by_ball b
    join wicket_taken w
      on b.match_id = w.match_id
     and b.over_id = w.over_id
     and b.ball_id = w.ball_id
     and b.innings_no = w.innings_no
    join out_type ot
      on w.kind_out = ot.out_id
    where ot.out_name not in ('run out','retired hurt','obstructing the field')
),

bowler_match as (
    select
        player_id,
        match_id,
        count(*) as wickets_in_match
    from valid_wickets
    group by player_id, match_id
)

select
    p.player_id,
    p.player_name,
    round(avg(wickets_in_match),2) as avg_wickets_per_match
from bowler_match bm
join player p
    on bm.player_id = p.player_id
group by p.player_id, p.player_name
order by avg_wickets_per_match desc;


-- Question 4: Which players offer versatility in their skills and can contribute effectively with both bat and ball? 

with batting_stats as (
    select
        b.striker as player_id,
        sum(b.runs_scored) as total_runs,
        count(distinct b.match_id) as matches_batted,
        round(sum(b.runs_scored) / count(distinct b.match_id),2) as avg_runs_per_match
    from ball_by_ball b
    group by b.striker
),

valid_wickets as (
    select
        b.bowler as player_id,
        b.match_id
    from ball_by_ball b
    join wicket_taken w
      on b.match_id = w.match_id
     and b.over_id = w.over_id
     and b.ball_id = w.ball_id
     and b.innings_no = w.innings_no
    join out_type ot
      on w.kind_out = ot.out_id
    where ot.out_name not in ('run out','retired hurt','obstructing the field')
),

bowling_stats as (
    select
        player_id,
        count(*) as total_wickets,
        count(distinct match_id) as matches_bowled,
        round(count(*) / count(distinct match_id),2) as avg_wickets_per_match
    from valid_wickets
    group by player_id
)

select
    p.player_id,
    p.player_name,
    bs.total_runs,
    bs.avg_runs_per_match,
    bw.total_wickets,
    bw.avg_wickets_per_match
from batting_stats bs
join bowling_stats bw
    on bs.player_id = bw.player_id
join player p
    on p.player_id = bs.player_id
where bs.total_runs >= 500
  and bw.total_wickets >= 20
order by bs.total_runs desc, bw.total_wickets desc;


-- Question 5: Are there players whose presence positively influences the morale and performance of the team? 

-- a) Team Win Percentage When Player Plays:

with player_matches as (
    select distinct
        b.match_id,
        b.striker as player_id
    from ball_by_ball b
),
team_results as (
    select
        m.match_id,
        m.match_winner
    from matches m
)
 select
    p.player_id,
    p.player_name,
    count(pm.match_id) as matches_played,
    sum(case when tr.match_winner = t.team_id then 1 else 0 end) as team_wins,
    round(
        sum(case when tr.match_winner = t.team_id then 1 else 0 end)
        / count(pm.match_id) * 100
    ,2) as win_percentage_when_played
from player_matches pm
join matches m
    on pm.match_id = m.match_id
join team t
    on m.team_1 = t.team_id or m.team_2 = t.team_id
join team_results tr
    on pm.match_id = tr.match_id
join player p
    on pm.player_id = p.player_id
group by p.player_id, p.player_name
having matches_played >= 50
order by win_percentage_when_played desc;




-- b) Match-Winning Contributions:

select
    p.player_id,
    p.player_name,
    sum(b.runs_scored) as runs_in_wins
from ball_by_ball b
join matches m
    on b.match_id = m.match_id
join player p
    on b.striker = p.player_id
where m.match_winner = m.team_1
   or m.match_winner = m.team_2
group by p.player_id, p.player_name
having sum(b.runs_scored)>1000
order by runs_in_wins desc;

-- c) Captaincy Impact (Leadership Effect):

select
    p.player_name,
    count(*) as matches_as_captain,
    sum(case when m.match_winner = m.team_1 
          or m.match_winner = m.team_2 then 1 else 0 end) as wins,
    round(
        sum(case when m.match_winner = m.team_1 
              or m.match_winner = m.team_2 then 1 else 0 end)
        / count(*) * 100
    ,2) as captain_win_percentage
from matches m
join player p
    on m.toss_winner = p.player_id
group by p.player_name
order by captain_win_percentage desc;

-- D) wins in presence of player
select * from 

-- Question 6: What would you suggest to RCB before going to the mega auction? 

-- 1) Identify Weak Death Bowling (Overs 16–20)

#If economy is high here → RCB must buy a death specialist.
select
    p.player_id,
    p.player_name,
    sum(b.runs_scored) as runs_conceded,
    count(*)/6 as overs_bowled,
    round(sum(b.runs_scored)/(count(*)/6),2) as death_economy
from ball_by_ball b
join matches m
    on b.match_id = m.match_id
join player p
    on b.bowler = p.player_id
where (m.team_1 = 2 or m.team_2 = 2)
  and b.over_id between 16 and 20
group by p.player_id, p.player_name
having overs_bowled >= 10
order by death_economy desc;

-- 2) Middle Order Instability (Batting Position 4–6)

#If avg is low → need stable middle-order batter

select
    p.player_id,
    p.player_name,
    sum(b.runs_scored) as total_runs,
    count(distinct b.match_id) as matches_played,
    round(sum(b.runs_scored)/count(distinct b.match_id),2) as avg_runs
from ball_by_ball b
join matches m
    on b.match_id = m.match_id
join player p
    on b.striker = p.player_id
where (m.team_1 = 2 or m.team_2 = 2)
  and b.innings_no = 1
group by p.player_id, p.player_name
having matches_played >= 10
order by avg_runs asc;


/* Question 7: What do you think could be the factors contributing to the high-scoring matches and the impact on viewership and team 
               strategies? */
               
    -- 1) Batting-Friendly Venues (Flat Pitches / Small Grounds)
    
    select
    v.venue_name,
    round(avg(total_runs),2) as avg_first_innings_score
from (
    select
        m.match_id,
        m.venue_id,
        sum(b.runs_scored) as total_runs
    from ball_by_ball b
    join matches m
        on b.match_id = m.match_id
    where b.innings_no = 1
    group by m.match_id, m.venue_id
) t
join venue v
    on t.venue_id = v.venue_id
group by v.venue_name
order by avg_first_innings_score desc;

-- 2) Death Overs Acceleration (Overs 16–20)

select
    m.season_id,
    round(sum(b.runs_scored)/(count(*)/6),2) as death_over_run_rate
from ball_by_ball b
join matches m
    on b.match_id = m.match_id
where b.over_id between 16 and 20
group by m.season_id
order by m.season_id;


-- 3) Powerplay Aggression (Overs 1–6)

select
    m.season_id,
    round(sum(b.runs_scored)/(count(*)/6),2) as powerplay_run_rate
from ball_by_ball b
join matches m
    on b.match_id = m.match_id
where b.over_id between 1 and 6
group by m.season_id
order by m.season_id;



-- Question 8: Analyze the impact of home-ground advantage on team performance and identify strategies to maximize this advantage for RCB.

--  Home vs Away Win Percentage (RCB)

select
    case
        when v.venue_name = 'M Chinnaswamy Stadium' then 'Home'
        else 'Away'
    end as venue_type,
    count(*) as matches_played,
    sum(case when m.match_winner = t.team_id then 1 else 0 end) as matches_won,
    round(
        sum(case when m.match_winner = t.team_id then 1 else 0 end)
        * 100.0 / count(*), 2
    ) as win_percentage
from matches m
join team t
    on t.team_name = 'Royal Challengers Bangalore'
join venue v
    on m.venue_id = v.venue_id
where m.team_1 = t.team_id
   or m.team_2 = t.team_id
group by venue_type;



/* Question 9: Come up with a visual and analytical analysis of the RCB's past season's performance and potential reasons for them
                   not winning a trophy. */


select
    b.striker as player_id,
    p.player_name,
    sum(b.runs_scored) as total_runs
from ball_by_ball b
join matches m
    on b.match_id = m.match_id
join player p
    on b.striker = p.player_id
where b.team_batting = 2
group by b.striker, p.player_name
order by total_runs desc
limit 10;



/* Question 11:In the "Match" table, some entries in the "Opponent_Team" column are incorrectly spelled as "Delhi_Capitals" instead of
			   "Delhi_Daredevils". Write an SQL query to replace all occurrences of "Delhi_Capitals" with "Delhi_Daredevils".*/
               
update Match
set Opponent_Team = 'Delhi_Daredevils'
where Opponent_Team = 'Delhi_Capitals';



