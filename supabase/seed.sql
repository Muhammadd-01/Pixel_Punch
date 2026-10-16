-- =============================================================================
-- PIXELPUNCH: SEED DATA
-- =============================================================================

INSERT INTO public.achievements (id, title, description, badge_icon, xp_reward)
VALUES
    ('first_blood', 'First Punch', 'Defeat your first fictional villain in any zone.', 'sports_mma', 50),
    ('bug_squasher', 'Bug Squasher', 'Defeat the Bug Phantom in the NexoVate Office District.', 'bug_report', 100),
    ('deadline_crusher', 'Beat the Clock', 'Defeat Captain Deadline before the match timer expires.', 'timer', 100),
    ('zone_master_office', 'Office Champion', 'Locate and defeat all villains in the NexoVate Office District.', 'domain', 200),
    ('trio_triumph', 'Dream Team', 'Win a 3v3 Squad battle with all 3 friendly heroes surviving.', 'groups', 150),
    ('speed_demon', 'Faster Than Lag', 'Defeat Lag Lord without taking more than 50 damage.', 'speed', 150)
ON CONFLICT (id) DO NOTHING;
