-- AI 生成课件素材/PPT 提纲（教师确认编辑后发布）
ALTER TABLE lesson_plan
    ADD COLUMN ppt_outline_json JSON NULL COMMENT 'AI 生成课件素材/PPT 提纲 JSON（教师确认编辑后使用）';