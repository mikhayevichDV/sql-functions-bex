CREATE OR REPLACE FUNCTION public.offert(
    job_id UUID,
    p_id UUID
)
RETURNS TABLE(
    id UUID,
    total_score DOUBLE PRECISION
) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        o.id,
        FLOOR(
            (
                (1 - (o.vector <=> j.vector)) * 0.5 + 
                (
                    SELECT 1 - (p.vector <=> j.vector)
                    FROM public.partner_freelancer_profiles p
                    WHERE p.id = o.profile_id
                ) * 0.2 +
                COALESCE((
                    SELECT 
                        SUM(
                            CASE 
                                WHEN rank = 1 THEN score * 0.5
                                WHEN rank = 2 THEN score * 0.3
                                WHEN rank = 3 THEN score * 0.2
                                ELSE 0
                            END
                        )
                    FROM (
                        SELECT 
                            1 - (ufpp.vector <=> j.vector) AS score,
                            ROW_NUMBER() OVER (ORDER BY 1 - (ufpp.vector <=> j.vector) DESC) AS rank
                        FROM public.upwork_freelancer_portfolio_projects ufpp
                        WHERE ufpp.profile_id = o.profile_id
                        ORDER BY score DESC
                        LIMIT 3
                    ) AS ranked_scores
                ), 0) * 0.3
            ) * 100
        ) AS total_score

    FROM public.offers o
    JOIN upwork.jobs j ON j.id = job_id
    WHERE o.partner_id = p_id;
END;
$$;