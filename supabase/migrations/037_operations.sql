-- ============================================================
-- Einsatzplaner (Operation Planner) — Schema
-- ============================================================

-- Join-Code Generator erweitern: auch operations prüfen
CREATE OR REPLACE FUNCTION generate_join_code()
RETURNS TEXT AS $$
DECLARE
    chars TEXT := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    code  TEXT := '';
    i     INT;
BEGIN
    LOOP
        code := '';
        FOR i IN 1..4 LOOP
            code := code || substr(chars, floor(random() * length(chars) + 1)::int, 1);
        END LOOP;
        IF NOT EXISTS (SELECT 1 FROM guide_sessions WHERE join_code = code)
           AND NOT EXISTS (SELECT 1 FROM operations WHERE join_code = code) THEN
            RETURN code;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- OPERATIONS — Offensive-Einsaetze (Container)
-- ============================================================
CREATE TABLE operations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_by      UUID NOT NULL REFERENCES profiles(id),
    kingdom_id      INT,
    join_code       TEXT UNIQUE DEFAULT generate_join_code(),
    title           TEXT NOT NULL,
    description     TEXT,
    world_speed     DOUBLE PRECISION NOT NULL DEFAULT 1.0,
    status          TEXT NOT NULL DEFAULT 'planning',
    visibility      TEXT NOT NULL DEFAULT 'full',
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER set_updated_at_operations
    BEFORE UPDATE ON operations FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE INDEX idx_operations_kingdom_id ON operations(kingdom_id);
CREATE INDEX idx_operations_kingdom_status ON operations(kingdom_id, status);
CREATE INDEX idx_operations_join_code ON operations(join_code);
CREATE INDEX idx_operations_created_by ON operations(created_by);

-- ============================================================
-- PLANNED_ATTACKS — Einzelne Angriffszuweisungen
-- ============================================================
CREATE TABLE planned_attacks (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    operation_id    UUID NOT NULL REFERENCES operations(id) ON DELETE CASCADE,
    assigned_to     UUID REFERENCES profiles(id),
    attack_type     TEXT NOT NULL DEFAULT 'attack',
    player_name     TEXT NOT NULL,
    village_name    TEXT NOT NULL,
    village_x       INT NOT NULL,
    village_y       INT NOT NULL,
    target_x        INT NOT NULL,
    target_y        INT NOT NULL,
    target_player   TEXT,
    target_village  TEXT,
    arrival         TIMESTAMPTZ NOT NULL,
    travel_seconds  DOUBLE PRECISION NOT NULL,
    departure_at    TIMESTAMPTZ NOT NULL,
    troop_speed     DOUBLE PRECISION NOT NULL DEFAULT 3.0,
    confirmed       BOOLEAN DEFAULT false,
    sent            BOOLEAN DEFAULT false,
    confirmed_at    TIMESTAMPTZ,
    sent_at         TIMESTAMPTZ,
    notes           TEXT,
    sort_order      INT DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER set_updated_at_planned_attacks
    BEFORE UPDATE ON planned_attacks FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE INDEX idx_planned_attacks_operation ON planned_attacks(operation_id);
CREATE INDEX idx_planned_attacks_assigned ON planned_attacks(assigned_to);
CREATE INDEX idx_planned_attacks_departure ON planned_attacks(departure_at);

-- ============================================================
-- OPERATION_MEMBERS — Mitglieder via Join-Code
-- ============================================================
CREATE TABLE operation_members (
    operation_id    UUID NOT NULL REFERENCES operations(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    joined_at       TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (operation_id, user_id)
);

CREATE INDEX idx_operation_members_user ON operation_members(user_id);
CREATE INDEX idx_operation_members_operation ON operation_members(operation_id);

-- ============================================================
-- RLS POLICIES
-- ============================================================

ALTER TABLE operations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Operations lesen"
    ON operations FOR SELECT
    USING (
        kingdom_id = public.get_my_kingdom_id()
        OR id IN (SELECT operation_id FROM operation_members WHERE user_id = auth.uid())
        OR created_by = auth.uid()
    );

CREATE POLICY "Operations erstellen"
    ON operations FOR INSERT
    WITH CHECK (
        created_by = auth.uid()
        AND public.get_my_role() IN ('duke', 'viceking', 'king', 'admin')
    );

CREATE POLICY "Operations aendern"
    ON operations FOR UPDATE
    USING (
        created_by = auth.uid()
        OR (
            kingdom_id = public.get_my_kingdom_id()
            AND public.get_my_role() IN ('duke', 'viceking', 'king', 'admin')
        )
    );

CREATE POLICY "Operations loeschen"
    ON operations FOR DELETE
    USING (
        created_by = auth.uid()
        OR public.get_my_role() IN ('king', 'admin')
    );

-- PLANNED_ATTACKS
ALTER TABLE planned_attacks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Planned Attacks lesen"
    ON planned_attacks FOR SELECT
    USING (
        operation_id IN (
            SELECT id FROM operations
            WHERE kingdom_id = public.get_my_kingdom_id()
               OR id IN (SELECT operation_id FROM operation_members WHERE user_id = auth.uid())
               OR created_by = auth.uid()
        )
    );

CREATE POLICY "Planned Attacks erstellen"
    ON planned_attacks FOR INSERT
    WITH CHECK (
        operation_id IN (
            SELECT id FROM operations
            WHERE created_by = auth.uid()
               OR (kingdom_id = public.get_my_kingdom_id()
                   AND public.get_my_role() IN ('duke', 'viceking', 'king', 'admin'))
        )
    );

CREATE POLICY "Planned Attacks aendern"
    ON planned_attacks FOR UPDATE
    USING (
        -- Planner darf alles aendern
        operation_id IN (
            SELECT id FROM operations
            WHERE created_by = auth.uid()
               OR (kingdom_id = public.get_my_kingdom_id()
                   AND public.get_my_role() IN ('duke', 'viceking', 'king', 'admin'))
        )
        -- ODER: Zugewiesener Spieler darf confirmed/sent aendern
        OR assigned_to = auth.uid()
    );

CREATE POLICY "Planned Attacks loeschen"
    ON planned_attacks FOR DELETE
    USING (
        operation_id IN (
            SELECT id FROM operations
            WHERE created_by = auth.uid()
               OR (kingdom_id = public.get_my_kingdom_id()
                   AND public.get_my_role() IN ('king', 'admin'))
        )
    );

-- OPERATION_MEMBERS
ALTER TABLE operation_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Operation Members lesen"
    ON operation_members FOR SELECT
    USING (
        operation_id IN (
            SELECT id FROM operations
            WHERE kingdom_id = public.get_my_kingdom_id()
               OR created_by = auth.uid()
        )
        OR user_id = auth.uid()
    );

CREATE POLICY "Selbst beitreten"
    ON operation_members FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Selbst verlassen"
    ON operation_members FOR DELETE
    USING (user_id = auth.uid());

-- ============================================================
-- REALTIME
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE operations;
ALTER PUBLICATION supabase_realtime ADD TABLE planned_attacks;
ALTER PUBLICATION supabase_realtime ADD TABLE operation_members;

ALTER TABLE operations REPLICA IDENTITY FULL;
ALTER TABLE planned_attacks REPLICA IDENTITY FULL;

-- ============================================================
-- NOTIFICATION bei Zuweisung
-- ============================================================
ALTER TABLE notification_preferences
    ADD COLUMN IF NOT EXISTS operation_assigned BOOLEAN DEFAULT true;

CREATE OR REPLACE FUNCTION create_attack_assignment_notification()
RETURNS TRIGGER AS $$
DECLARE
    op_title TEXT;
    op_kingdom_id INT;
    planner_name TEXT;
    planner_id UUID;
BEGIN
    IF NEW.assigned_to IS NULL THEN RETURN NEW; END IF;

    SELECT o.title, o.kingdom_id, o.created_by, p.player_name
    INTO op_title, op_kingdom_id, planner_id, planner_name
    FROM operations o
    JOIN profiles p ON p.id = o.created_by
    WHERE o.id = NEW.operation_id;

    IF planner_id = NEW.assigned_to THEN RETURN NEW; END IF;

    IF EXISTS (
        SELECT 1 FROM notification_preferences
        WHERE user_id = NEW.assigned_to AND operation_assigned = false
    ) THEN
        RETURN NEW;
    END IF;

    INSERT INTO notifications (user_id, kingdom_id, type, title, body, reference_id, reference_type, actor_id, actor_name)
    VALUES (
        NEW.assigned_to,
        op_kingdom_id,
        'operation_assigned',
        'Einsatz-Zuweisung',
        COALESCE(planner_name, 'Planer') || ' hat dir einen Angriff in "' || COALESCE(op_title, 'Operation') || '" zugewiesen',
        NEW.operation_id,
        'operation',
        planner_id,
        COALESCE(planner_name, 'Unbekannt')
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_attack_assigned_notification
    AFTER INSERT ON planned_attacks
    FOR EACH ROW
    EXECUTE FUNCTION create_attack_assignment_notification();
