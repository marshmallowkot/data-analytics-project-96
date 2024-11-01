--Расходы на рекламу по модели атрибуции Last Paid Click, 
--топ-15 записей согласно требованиям по сортировке
WITH tab AS (
    SELECT
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost,
        TO_CHAR(campaign_date, 'YYYY-MM-DD') AS campaign_date
    FROM vk_ads
    WHERE utm_medium != 'organic'
    GROUP BY utm_source, utm_medium, utm_campaign, campaign_date
    UNION ALL
    SELECT
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost,
        TO_CHAR(campaign_date, 'YYYY-MM-DD') AS campaign_date
    FROM ya_ads
    WHERE utm_medium != 'organic'
    GROUP BY utm_source, utm_medium, utm_campaign, campaign_date
),
tab3 AS (
    SELECT
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        s.visitor_id,
        l.lead_id,
        l.closing_reason,
        l.status_id,
        l.amount,
        ROW_NUMBER() OVER (PARTITION BY s.visitor_id ORDER BY s.visit_date DESC)
        AS rn,
        TO_CHAR(s.visit_date, 'YYYY-MM-DD') AS visit_date,
        LOWER(s.source) AS utm_source,
        TO_CHAR(l.created_at, 'YYYY-MM-DD') AS created_at
    FROM sessions AS s
    LEFT JOIN
        leads AS l
        ON
            s.visitor_id = l.visitor_id
            AND s.visit_date <= l.created_at
    WHERE s.medium != 'organic'
),
tab2 AS (
    SELECT
        tab3.rn,
        tab3.visit_date,
        tab3.utm_source,
        tab3.utm_medium,
        tab3.utm_campaign,
        tab.total_cost,
        COUNT(tab3.visitor_id) AS visitors_count,
        COUNT(tab3.lead_id) AS leads_count,
        COUNT(
            CASE
                WHEN
                    tab3.closing_reason = 'Успешно реализовано'
                    OR
                    tab3.status_id = '142'
                    THEN 1
            END
        ) AS purchases_count,
        SUM(CASE WHEN tab3.status_id = '142' THEN tab3.amount ELSE 0 END)
        AS revenue
    FROM
        tab3
    LEFT JOIN
        tab
        ON
            tab3.utm_campaign = tab.utm_campaign
            AND tab3.utm_medium = tab.utm_medium
            AND tab3.utm_source = tab.utm_source
            AND tab3.visit_date >= tab.campaign_date
    WHERE tab3.rn = 1
    GROUP BY
        tab3.rn, tab3.visit_date, tab3.utm_source, tab3.utm_medium,
        tab3.utm_campaign, tab.total_cost
)
SELECT
    visit_date,
    visitors_count,
    utm_source,
    utm_medium,
    utm_campaign,
    total_cost,
    leads_count,
    purchases_count,
    revenue
FROM tab2
ORDER BY
    revenue DESC NULLS LAST, visit_date ASC, visitors_count DESC,
    utm_source ASC, utm_medium ASC, utm_campaign ASC
LIMIT 15;
