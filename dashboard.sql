-- таблица results

with visitors_and_leads as (
    select distinct on (s.visitor_id)
        s.visitor_id,
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.amount,
        l.created_at,
        l.status_id
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
    order by 1, 2 desc
),

costs as (
    select
        campaign_date::date,
        SUM(daily_spent) as daily_spent,
        utm_source,
        utm_medium,
        utm_campaign
    from vk_ads
    group by 1, 3, 4, 5
    union all
    select
        campaign_date::date,
        SUM(daily_spent) as daily_spent,
        utm_source,
        utm_medium,
        utm_campaign
    from ya_ads
    group by 1, 3, 4, 5
),

results as (
    select
        vl.visit_date::date,
        COUNT(*) as visitors_count,
        vl.utm_source,
        vl.utm_medium,
        vl.utm_campaign,
        daily_spent as total_cost,
        COUNT(*) filter (where lead_id is not NULL) as leads_count,
        COUNT(*) filter (where status_id = 142) as purchases_count,
        COALESCE(SUM(amount) filter (where status_id = 142), 0) as revenue
    from visitors_and_leads as vl
    left join costs as c
        on
            vl.utm_source = c.utm_source
            and vl.utm_medium = c.utm_medium
            and vl.utm_campaign = c.utm_campaign
            and vl.visit_date::date = c.campaign_date::date
    group by 1, 3, 4, 5, 6
    order by 9 desc nulls last, 2 desc, 1, 3, 4, 5
)


-- общее количество посетителей, лидов, успешно завершенных сделок, каналов привлечения

select
    SUM(visitors_count),
    SUM(leads_count),
    SUM(purchases_count),
    COUNT(distinct utm_source) as count_utm_source
from results;


-- количество посетителей по каждому каналу по неделям

select
    case
        when visit_date between '2023-06-01' and '2023-06-04' then '1_week'
        when visit_date between '2023-06-05' and '2023-06-11' then '2_week'
        when visit_date between '2023-06-12' and '2023-06-18' then '3_week'
        when visit_date between '2023-06-19' and '2023-06-25' then '4_week'
        when visit_date between '2023-06-26' and '2023-06-30' then '5_week'
    end
    as week,
    utm_source,
    SUM(visitors_count) as visitors_count
from results
group by 1, 2
order by 1, 3 desc;


-- конверсия из клика в лид, из лида в оплату

select
    ROUND(SUM(leads_count) / SUM(visitors_count) * 100, 2) as conversion_leads,
    ROUND(SUM(purchases_count) / SUM(leads_count) * 100, 2) as conversion_paid
from results;

--Воронка

SELECT
    metric AS metric,
    sum(count) AS sm_cn
FROM
    (SELECT
        'Visits' AS metric,
        count(*) AS count
    FROM sessions
    UNION ALL
    SELECT
        'Leads' AS metric,
        count(*)
    FROM leads
    UNION ALL
    SELECT
        'Positive Leads' AS metric,
        count(*)
    FROM leads
    WHERE amount > 0) AS virtual_table
GROUP BY metric;

-- суммарные затраты на рекламу и суммарная выручка

select
    SUM(total_cost),
    SUM(revenue)
from results;

--Расчёт общего количества визитов
SELECT sum(count) AS visitors_count
FROM
    (SELECT
        sessions.source,
        sessions.medium,
        to_char(date_trunc('day', visit_date), 'YYYY-MM-DD') AS date,
        count(visitor_id),
        count(DISTINCT visitor_id) AS count_distinct
    FROM sessions
    GROUP BY
        3,
        sessions.source,
        sessions.medium
    ORDER BY date) AS virtual_table;


--Расчёт количества уникальных визитов
select COUNT(distinct(visitor_id)) as distinct_visitors_count
from sessions;

--Ежедневные визиты
SELECT
    date AS date,
    sum(count) AS visitors_count
FROM
    (SELECT
        sessions.source,
        sessions.medium,
        to_char(date_trunc('day', visit_date), 'YYYY-MM-DD') AS date,
        count(visitor_id)
    FROM sessions
    GROUP BY
        3,
        sessions.source,
        sessions.medium
    ORDER BY date) AS virtual_table
GROUP BY date
ORDER BY visitors_count DESC;


--Визиты по неделям
SELECT
    monday_date AS monday_date,
    sum(count) AS visitors_count
FROM
    (SELECT
        sessions.source,
        sessions.medium,
        count(visitor_id),
        to_char(date_trunc('week', visit_date), 'YYYY-MM-DD') AS monday_date
    FROM sessions
    GROUP BY
        monday_date,
        sessions.source,
        sessions.medium
    ORDER BY monday_date) AS virtual_table
GROUP BY monday_date
ORDER BY visitors_count DESC;


--Визиты по дням недели
SELECT
    day_of_week_combined AS day_of_week_combined,
    sum(count) AS visitors_count
FROM
    (SELECT
        sessions.source,
        sessions.medium,
        count(visitor_id),
        (extract(
            ISODOW
            FROM visit_date
        )::TEXT || '.' || to_char(visit_date, 'Day'
        )) AS day_of_week_combined
    FROM sessions
    GROUP BY
        day_of_week_combined,
        sessions.source,
        sessions.medium
    ORDER BY day_of_week_combined) AS virtual_table
GROUP BY day_of_week_combined
ORDER BY visitors_count DESC;


--ТОП 10 Source по количеству визитов
SELECT
    source AS source,
    sum(count) AS visitors_count
FROM
    (SELECT
        sessions.source,
        sessions.medium,
        to_char(date_trunc('day', visit_date), 'YYYY-MM-DD') AS date,
        count(visitor_id),
        count(DISTINCT visitor_id) AS count_distinct
    FROM sessions
    GROUP BY
        3,
        sessions.source,
        sessions.medium
    ORDER BY date) AS virtual_table
GROUP BY source
ORDER BY visitors_count DESC
LIMIT 10;


--ТОП 10 medium по количеству визитов
SELECT
    medium AS medium,
    sum(count) AS visitors_count
FROM
    (SELECT
        sessions.source,
        sessions.medium,
        to_char(date_trunc('day', visit_date), 'YYYY-MM-DD') AS date,
        count(visitor_id),
        count(DISTINCT visitor_id) AS count_distinct
    FROM sessions
    GROUP BY
        3,
        sessions.source,
        sessions.medium
    ORDER BY date) AS virtual_table
GROUP BY medium
ORDER BY visitors_count DESC;


--Количество лидов
SELECT sum(leed) AS leads_count
FROM
    (SELECT
        1 AS leed,
        amount,
        closing_reason,
        CASE
            WHEN amount > 0 THEN 1
            ELSE 0
        END AS leed_amount,
        to_char(date_trunc('day', created_at), 'YYYY-MM-DD') AS date
    FROM leads
    ORDER BY date) AS virtual_table;


--Количество Purchases_count
SELECT sum(leed_amount) AS Purchases_count
FROM
    (SELECT
        1 AS leed,
        amount,
        closing_reason,
        CASE
            WHEN amount > 0 THEN 1
            ELSE 0
        END AS leed_amount,
        to_char(date_trunc('day', created_at), 'YYYY-MM-DD') AS date
    FROM leads
    ORDER BY date) AS virtual_table;


--Процент лидов совершивших покупку к общему количеству лидов (Конверсия)
SELECT SUM(leed_amount) * 100 / SUM(leed) AS "Purchases_count/leads_count"
FROM
    (SELECT
        1 AS leed,
        amount,
        closing_reason,
        CASE
            WHEN amount > 0 THEN 1
            ELSE 0
        END AS leed_amount,
        TO_CHAR(DATE_TRUNC('day', created_at), 'YYYY-MM-DD') AS date
    FROM leads
    ORDER BY date) AS virtual_table;


--Доход
SELECT sum(amount) AS revenue
FROM
    (SELECT
        1 AS leed,
        amount,
        closing_reason,
        CASE
            WHEN amount > 0 THEN 1
            ELSE 0
        END AS leed_amount,
        to_char(date_trunc('day', created_at), 'YYYY-MM-DD') AS date
    FROM leads
    ORDER BY date) AS virtual_table;


--Средний чек
SELECT AVG(amount) AS AVG_chek
FROM
    (SELECT
        1 AS leed,
        amount,
        closing_reason,
        CASE
            WHEN amount > 0 THEN 1
            ELSE 0
        END AS leed_amount,
        TO_CHAR(DATE_TRUNC('day', created_at), 'YYYY-MM-DD') AS date
    FROM leads
    ORDER BY date) AS virtual_table
WHERE amount > 0;


--Ежедневные продажи
SELECT
    date AS date,
    sum(amount) AS revenue
FROM
    (SELECT
        1 AS leed,
        amount,
        closing_reason,
        CASE
            WHEN amount > 0 THEN 1
            ELSE 0
        END AS leed_amount,
        to_char(date_trunc('day', created_at), 'YYYY-MM-DD') AS date
    FROM leads
    ORDER BY date) AS virtual_table
GROUP BY date
ORDER BY date asc;


--Расходы
SELECT sum(total_daily_spent) AS consumption
FROM
    (
        SELECT
            campaign_name,
            utm_source,
            utm_medium,
            utm_campaign,
            utm_content,
            campaign_date,
            sum(daily_spent) AS total_daily_spent
        FROM
            (SELECT
                campaign_name,
                utm_source,
                utm_medium,
                utm_campaign,
                utm_content,
                campaign_date,
                daily_spent
            FROM vk_ads
            UNION ALL
            SELECT
                campaign_name,
                utm_source,
                utm_medium,
                utm_campaign,
                utm_content,
                campaign_date,
                daily_spent
            FROM ya_ads) AS combined_ads
        GROUP BY
            campaign_name,
            utm_source,
            utm_medium,
            utm_campaign,
            utm_content,
            campaign_date
    ) AS virtual_table;


--Расходы на yandex
SELECT sum(total_daily_spent) AS consumption_ya
FROM
    (
        SELECT
            campaign_name,
            utm_source,
            utm_medium,
            utm_campaign,
            utm_content,
            campaign_date,
            sum(daily_spent) AS total_daily_spent
        FROM
            (SELECT
                campaign_name,
                utm_source,
                utm_medium,
                utm_campaign,
                utm_content,
                campaign_date,
                daily_spent
            FROM vk_ads
            UNION ALL
            SELECT
                campaign_name,
                utm_source,
                utm_medium,
                utm_campaign,
                utm_content,
                campaign_date,
                daily_spent
            FROM ya_ads) AS combined_ads
        GROUP BY
            campaign_name,
            utm_source,
            utm_medium,
            utm_campaign,
            utm_content,
            campaign_date
    ) AS virtual_table
WHERE utm_source IN ('yandex');


--Расходы на vk
SELECT sum(total_daily_spent) AS consumption_vk
FROM
    (
        SELECT
            campaign_name,
            utm_source,
            utm_medium,
            utm_campaign,
            utm_content,
            campaign_date,
            sum(daily_spent) AS total_daily_spent
        FROM
            (SELECT
                campaign_name,
                utm_source,
                utm_medium,
                utm_campaign,
                utm_content,
                campaign_date,
                daily_spent
            FROM vk_ads
            UNION ALL
            SELECT
                campaign_name,
                utm_source,
                utm_medium,
                utm_campaign,
                utm_content,
                campaign_date,
                daily_spent
            FROM ya_ads) AS combined_ads
        GROUP BY
            campaign_name,
            utm_source,
            utm_medium,
            utm_campaign,
            utm_content,
            campaign_date
    ) AS virtual_table
WHERE utm_source IN ('vk');


--Расходы по utm_source
SELECT
    utm_source AS utm_source,
    sum(total_daily_spent) AS consumption_utm_source
FROM
    (
        SELECT
            campaign_name,
            utm_source,
            utm_medium,
            utm_campaign,
            utm_content,
            campaign_date,
            sum(daily_spent) AS total_daily_spent
        FROM
            (SELECT
                campaign_name,
                utm_source,
                utm_medium,
                utm_campaign,
                utm_content,
                campaign_date,
                daily_spent
            FROM vk_ads
            UNION ALL
            SELECT
                campaign_name,
                utm_source,
                utm_medium,
                utm_campaign,
                utm_content,
                campaign_date,
                daily_spent
            FROM ya_ads) AS combined_ads
        GROUP BY
            campaign_name,
            utm_source,
            utm_medium,
            utm_campaign,
            utm_content,
            campaign_date
    ) AS virtual_table
GROUP BY utm_source
ORDER BY consumption_utm_source DESC;

-- CPU, CPL, CPPU, ROI

select
    ROUND(COALESCE(SUM(total_cost), 0) / SUM(visitors_count), 2) as cpu,
    ROUND(COALESCE(SUM(total_cost), 0) / SUM(leads_count), 2) as cpl,
    ROUND(COALESCE(SUM(total_cost), 0) / SUM(purchases_count), 2) as cppu,
    ROUND((SUM(revenue) - SUM(total_cost)) / SUM(total_cost) * 100, 2) as roi
from results;


-- CPU, CPL, CPPU, ROI по utm_sourse

select
    utm_source,
    ROUND(COALESCE(SUM(total_cost), 0) / SUM(visitors_count), 2) as cpu,
    ROUND(COALESCE(SUM(total_cost), 0) / SUM(leads_count), 2) as cpl,
    ROUND(COALESCE(SUM(total_cost), 0) / SUM(purchases_count), 2) as cppu,
    ROUND((SUM(revenue) - SUM(total_cost)) / SUM(total_cost) * 100, 2) as roi
from results
group by 1
having SUM(total_cost) is not null;


-- CPU по utm_medium

select
    utm_medium,
    ROUND(COALESCE(SUM(total_cost), 0) / SUM(visitors_count), 2) as cpu
from results
group by 1
having SUM(visitors_count) != 0;


-- CPL по utm_medium

select
    utm_medium,
    ROUND(COALESCE(SUM(total_cost), 0) / SUM(leads_count), 2) as cpl
from results
group by 1
having SUM(leads_count) != 0;


-- CPPU по utm_medium

select
    utm_medium,
    ROUND(COALESCE(SUM(total_cost), 0) / SUM(purchases_count), 2) as cppu
from results
group by 1
having SUM(purchases_count) != 0;


-- ROI по utm_medium

select
    utm_medium,
    ROUND((SUM(revenue) - SUM(total_cost)) / SUM(total_cost) * 100, 2) as roi
from results
group by 1
having SUM(total_cost) != 0;


-- CPU по utm_campaign

select
    utm_campaign,
    round(coalesce(sum(total_cost), 0) / sum(visitors_count), 2) as cpu
from results
group by 1
having sum(visitors_count) != 0
order by 2 desc;


-- CPL по utm_campaign

select
    utm_campaign,
    round(coalesce(sum(total_cost), 0) / sum(leads_count), 2) as cpl
from results
group by 1
having sum(leads_count) != 0
order by 2 desc;


-- CPPU по utm_campaign

select
    utm_campaign,
    round(coalesce(sum(total_cost), 0) / sum(purchases_count), 2) as cppu
from results
group by 1
having sum(purchases_count) != 0
order by 2 desc;


-- ROI по utm_campaign

select
    utm_campaign,
    round((sum(revenue) - sum(total_cost)) / sum(total_cost) * 100, 2) as roi
from results
group by 1
having sum(total_cost) != 0
order by 2 desc;


-- затраты на рекламу, выручка по каналам

select
    utm_source,
    sum(coalesce(total_cost, 0)) as source_total_cost,
    sum(coalesce(revenue, 0)) as source_revenue
from results
group by 1
order by 2 desc, 3 desc;


-- корреляция между запуском рекламной кампании и ростом органики:

with organic as (
    select
        visit_date::date as visit_date,
        COUNT(*) as count_organic
    from sessions
    where medium = 'organic'
    group by 1
),

daily_costs as (
    select
        utm_source,
        utm_medium,
        utm_campaign,
        utm_content,
        daily_spent
    from vk_ads
    union all
    select
        utm_source,
        utm_medium,
        utm_campaign,
        utm_content,
        daily_spent
    from ya_ads
),

source_and_costs as (
    select
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        s.content as utm_content,
        dc.daily_spent
    from sessions as s
    inner join daily_costs as dc
        on
            s.source = dc.utm_source
            and s.medium = dc.utm_medium
            and s.campaign = dc.utm_campaign
            and s.content = dc.utm_content
),

total_costs as (
    select
        visit_date::date as visit_date,
        SUM(daily_spent) as total_cost
    from source_and_costs
    group by 1
)

select
    o.visit_date,
    tc.total_cost,
    o.count_organic
from organic as o
inner join total_costs as tc
    on o.visit_date = tc.visit_date
order by 1;

-- дата закрытия лидов

with table1 as (
    select distinct on (s.visitor_id)
        s.visitor_id,
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
    order by 1, 2 desc
),

visitors_and_leads as (
    select * from table1
    order by 8 desc nulls last, 2, 3, 4, 5
),

date_close as (
    select
        lead_id,
        created_at as date_close
    from visitors_and_leads
    where lead_id is not null
    order by 2
)

select
    date_close::date,
    COUNT(*) as leads_count
from date_close
group by 1
order by 1;


-- кол-во дней с момента перехода по рекламе до закрытия лида

with table1 as (
    select distinct on (s.visitor_id)
        s.visitor_id,
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
    order by 1, 2 desc
),

visitors_and_leads as (
    select * from table1
    order by 8 desc nulls last, 2, 3, 4, 5
),

days_close as (
    select
        lead_id,
        created_at::date - visit_date::date as days_close
    from visitors_and_leads
    where lead_id is not null
    order by 2
)

select
    days_close,
    COUNT(*) as leads_count
from days_close
group by 1
order by 1;

--Сводная таблица
with tab as (
    select
        sessions.visitor_id,
        visit_date,
        source,
        medium,
        campaign,
        created_at,
        closing_reason,
        status_id,
        coalesce(amount, 0) as amount,
        case
            when created_at < visit_date then 'delete' else lead_id
        end as lead_id,
        row_number()
            over (partition by sessions.visitor_id order by visit_date desc)
        as rn
    from sessions
    left join leads
        on sessions.visitor_id = leads.visitor_id
    where medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),

tab2 as (
    select
        tab.visitor_id,
        tab.source as utm_source,
        tab.medium as utm_medium,
        tab.campaign as utm_campaign,
        tab.created_at,
        tab.amount,
        tab.closing_reason,
        tab.status_id,
        date_trunc('day', tab.visit_date) as visit_date,
        case
            when tab.created_at < tab.visit_date then 'delete' else lead_id
        end as lead_id
    from tab
    where (tab.lead_id != 'delete' or tab.lead_id is null) and tab.rn = 1
),

amount as (
    select
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        count(visitor_id) as visitors_count,
        sum(case when lead_id is not null then 1 else 0 end) as leads_count,
        sum(
            case
                when
                    closing_reason = 'Успешная продажа' or status_id = 142
                    then 1
                else 0
            end
        ) as purchases_count,
        sum(amount) as revenue
    from tab2
    group by
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign
),

tab4 as (
    select
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        daily_spent
    from vk_ads
    union all
    select
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        daily_spent
    from ya_ads
),

cost as (
    select
        campaign_date as visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from tab4
    group by
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign
),

tab5 as (
    select
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        null as revenue,
        null as visitors_count,
        null as leads_count,
        null as purchases_count,
        total_cost
    from cost
    union all
    select
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        revenue,
        visitors_count,
        leads_count,
        purchases_count,
        null as total_cost
    from amount
),
tab6 as (
select
    utm_source,
    utm_medium,
    utm_campaign,
    sum(coalesce(visitors_count, 0)) as visitors_count,
    sum(coalesce(total_cost, 0)) as total_cost,
    sum(coalesce(leads_count, 0)) as leads_count,
    sum(coalesce(purchases_count, 0)) as purchases_count,
    sum(coalesce(revenue, 0)) as revenue
from tab5
group by
    utm_source,
    utm_medium,
    utm_campaign
order by total_cost desc
)
select *,
    CASE WHEN visitors_count = 0 THEN NULL ELSE total_cost / visitors_count END AS cpu,
    CASE WHEN leads_count = 0 THEN NULL ELSE total_cost / leads_count END AS cpl,
    CASE WHEN purchases_count = 0 THEN NULL ELSE total_cost / purchases_count END AS cppu,
    CASE WHEN total_cost = 0 THEN NULL ELSE ((revenue - total_cost) / total_cost) * 100 END AS roi
FROM tab6
order by roi;