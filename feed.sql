CREATE OR REPLACE FUNCTION feeds(
  p_id uuid,
  p_offset integer DEFAULT 0,
  p_start_date TIMESTAMPTZ DEFAULT '1970-01-01',
  p_end_date TIMESTAMPTZ DEFAULT '9999-12-31',
  p_scoring_value_from DOUBLE PRECISION DEFAULT 0,
  p_scoring_value_to DOUBLE PRECISION DEFAULT 100,
  p_title_start TEXT DEFAULT '',
  p_offer_ids UUID[] DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    title CHARACTER VARYING,
    description CHARACTER VARYING,
    job_type jobs_job_type_enum,
    category CHARACTER VARYING,
    project_length CHARACTER VARYING,
    client_payment_verified boolean,
    client_location CHARACTER VARYING,
    hours_per_week CHARACTER VARYING,
    experience_level int,
    connect_price int,
    publish_time TIMESTAMPTZ,
    hourly_budget_min DOUBLE PRECISION,
    hourly_budget_max DOUBLE PRECISION,
    budget_amount DOUBLE PRECISION,
    created_at TIMESTAMP WITH TIME ZONE,
    offer_similarity DOUBLE PRECISION,
    portfolio_similarity DOUBLE PRECISION,
    profile_similarity DOUBLE PRECISION,
    best_vector_similarity DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        jobs.id, 
        jobs.title,
        jobs.description, 
        jobs.job_type,
        jobs.category,
        jobs.project_length,
        jobs.client_payment_verified,
        jobs.client_location,
        jobs.hours_per_week,
        jobs.experience_level,
        jobs.connect_price,
        jobs.publish_time, 
        jobs.hourly_budget_min, 
        jobs.hourly_budget_max, 
        jobs.budget_amount, 
        jobs.created_at, 
        
        (SELECT MAX(1 - (jobs.vector <=> offers.vector)) 
         FROM offers 
         WHERE offers.partner_id = p_id
           AND (p_offer_ids IS NULL OR ARRAY_LENGTH(p_offer_ids, 1) = 0 OR offers.id = ANY(p_offer_ids))) AS offer_similarity,
        
        (SELECT COALESCE(1 - (0.5 * scores[1] + 0.3 * scores[2] + 0.2 * scores[3]), 0) 
         FROM (
             SELECT ARRAY(
                 SELECT (1 - (upwork_freelancer_portfolio_projects.vector <=> jobs.vector)) 
                 FROM upwork_freelancer_portfolio_projects 
                 WHERE upwork_freelancer_portfolio_projects.profile_id = (
                     SELECT profile_id 
                     FROM offers 
                     WHERE offers.partner_id = p_id 
                       AND (p_offer_ids IS NULL OR ARRAY_LENGTH(p_offer_ids, 1) = 0 OR offers.id = ANY(p_offer_ids))
                     ORDER BY (1-(jobs.vector <=> offers.vector)) DESC 
                     LIMIT 1
                 )
                 ORDER BY (1-(upwork_freelancer_portfolio_projects.vector <=> jobs.vector)) DESC 
                 LIMIT 3
             ) AS scores
         ) subquery) AS portfolio_similarity,
        
        (SELECT 1 - (partner_freelancer_profiles.vector <=> jobs.vector) 
         FROM partner_freelancer_profiles 
         WHERE partner_freelancer_profiles.id = (
             SELECT profile_id 
             FROM offers 
             WHERE offers.partner_id = p_id 
               AND (p_offer_ids IS NULL OR ARRAY_LENGTH(p_offer_ids, 1) = 0 OR offers.id = ANY(p_offer_ids))
             ORDER BY (1-(jobs.vector <=> offers.vector)) DESC 
             LIMIT 1
         )) AS profile_similarity,
        
        FLOOR(
            (0.5 * (SELECT MAX(1 - (jobs.vector <=> offers.vector)) 
                    FROM offers 
                    WHERE offers.partner_id = p_id
                      AND (p_offer_ids IS NULL OR ARRAY_LENGTH(p_offer_ids, 1) = 0 OR offers.id = ANY(p_offer_ids))) +
             0.3 * (SELECT COALESCE(1 - (0.5 * scores[1] + 0.3 * scores[2] + 0.2 * scores[3]), 0) 
                    FROM (
                        SELECT ARRAY(
                            SELECT (1 - (upwork_freelancer_portfolio_projects.vector <=> jobs.vector)) 
                            FROM upwork_freelancer_portfolio_projects 
                            WHERE upwork_freelancer_portfolio_projects.profile_id = (
                                SELECT profile_id 
                                FROM offers 
                                WHERE offers.partner_id = p_id 
                                  AND (p_offer_ids IS NULL OR ARRAY_LENGTH(p_offer_ids, 1) = 0 OR offers.id = ANY(p_offer_ids))
                                ORDER BY (1-(jobs.vector <=> offers.vector)) DESC 
                                LIMIT 1
                            )
                            ORDER BY (1-(upwork_freelancer_portfolio_projects.vector <=> jobs.vector)) DESC 
                            LIMIT 3
                        ) AS scores
                    ) subquery) +
             0.2 * (SELECT 1 - (partner_freelancer_profiles.vector <=> jobs.vector) 
                    FROM partner_freelancer_profiles 
                    WHERE partner_freelancer_profiles.id = (
                        SELECT profile_id 
                        FROM offers 
                        WHERE offers.partner_id = p_id 
                          AND (p_offer_ids IS NULL OR ARRAY_LENGTH(p_offer_ids, 1) = 0 OR offers.id = ANY(p_offer_ids))
                        ORDER BY (1-(jobs.vector <=> offers.vector)) DESC 
                        LIMIT 1
                    )
                   )
            ) * 100
        ) AS best_vector_similarity
    FROM upwork.jobs
    WHERE jobs.publish_time BETWEEN p_start_date AND p_end_date
    AND FLOOR(
            (0.5 * (SELECT MAX(1 - (jobs.vector <=> offers.vector)) 
                    FROM offers 
                    WHERE offers.partner_id = p_id
                      AND (p_offer_ids IS NULL OR ARRAY_LENGTH(p_offer_ids, 1) = 0 OR offers.id = ANY(p_offer_ids))) +
             0.3 * (SELECT COALESCE(1 - (0.5 * scores[1] + 0.3 * scores[2] + 0.2 * scores[3]), 0) 
                    FROM (
                        SELECT ARRAY(
                            SELECT 1 - (upwork_freelancer_portfolio_projects.vector <=> jobs.vector) 
                            FROM upwork_freelancer_portfolio_projects 
                            WHERE upwork_freelancer_portfolio_projects.profile_id = (
                                SELECT profile_id 
                                FROM offers 
                                WHERE offers.partner_id = p_id 
                                  AND (p_offer_ids IS NULL OR ARRAY_LENGTH(p_offer_ids, 1) = 0 OR offers.id = ANY(p_offer_ids))
                                ORDER BY (1-(jobs.vector <=> offers.vector)) DESC 
                                LIMIT 1
                            )
                            ORDER BY (1-(upwork_freelancer_portfolio_projects.vector <=> jobs.vector)) DESC 
                            LIMIT 3
                        ) AS scores
                    ) subquery) +
             0.2 * (SELECT 1 - (partner_freelancer_profiles.vector <=> jobs.vector) 
                    FROM partner_freelancer_profiles 
                    WHERE partner_freelancer_profiles.id = (
                        SELECT profile_id 
                        FROM offers 
                        WHERE offers.partner_id = p_id 
                          AND (p_offer_ids IS NULL OR ARRAY_LENGTH(p_offer_ids, 1) = 0 OR offers.id = ANY(p_offer_ids))
                        ORDER BY (1-(jobs.vector <=> offers.vector)) DESC 
                        LIMIT 1
                    )
                   )
            ) * 100
        ) BETWEEN p_scoring_value_from AND p_scoring_value_to
    ORDER BY jobs.publish_time DESC
    LIMIT 50
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;
