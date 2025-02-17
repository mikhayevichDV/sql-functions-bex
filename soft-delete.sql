DECLARE
    freelancer_updated BOOLEAN := FALSE;
    profile_updated BOOLEAN := FALSE;
    portfolio_projects_updated BOOLEAN := FALSE;
    partner_id_var UUID;
BEGIN
    -- Проверяем email пользователя
    IF user_email != auth.jwt() ->> 'email' THEN
        RAISE EXCEPTION 'User email does not match current user';
    END IF;

    -- Получаем partner_id для проверки
    SELECT partner_id INTO partner_id_var
    FROM partner_freelancers
    WHERE id = target_id;

    -- Проверяем partner_id
    IF partner_id_var != (auth.jwt() -> 'user_metadata'->>'partner_id')::uuid THEN
        RAISE EXCEPTION 'Partner ID does not match';
    END IF;

    -- Обновляем freelancer
    UPDATE partner_freelancers
    SET
        deleted_at = NOW(),
        deleted_by = user_email
    WHERE id = target_id
        AND deleted_at IS NULL;

    GET DIAGNOSTICS freelancer_updated = ROW_COUNT;

    -- Обновляем profile если freelancer был обновлен
    IF freelancer_updated THEN
        DECLARE
            profile_id_var UUID;
        BEGIN
            -- Обновляем профиль и получаем его ID
            WITH updated_profiles AS (
                UPDATE partner_freelancer_profiles
                SET
                    deleted_at = NOW(),
                    deleted_by = user_email
                WHERE freelancer_id = target_id
                    AND deleted_at IS NULL
                RETURNING id
            )
            SELECT id INTO profile_id_var FROM updated_profiles;

            GET DIAGNOSTICS profile_updated = ROW_COUNT;

            -- Если профиль был обновлен, обновляем проекты портфолио
            IF profile_updated AND profile_id_var IS NOT NULL THEN
                UPDATE upwork_freelancer_portfolio_projects
                SET
                    deleted_at = NOW(),
                    deleted_by = user_email
                WHERE profile_id = profile_id_var
                    AND deleted_at IS NULL;

                GET DIAGNOSTICS portfolio_projects_updated = ROW_COUNT;
            END IF;
        END;
    END IF;

    -- Если ничего не обновилось - ошибка
    IF NOT freelancer_updated THEN
        RAISE EXCEPTION 'Freelancer not found or already deleted';
    END IF;

    RETURN json_build_object(
        'freelancer_updated', freelancer_updated,
        'profile_updated', profile_updated,
        'portfolio_projects_updated', portfolio_projects_updated
    );

EXCEPTION WHEN OTHERS THEN
    -- В случае любой ошибки транзакция автоматически откатится
    RAISE;
END;
