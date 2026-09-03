-- 2026-09-03 病例科室纠偏（内容与科室标签对齐，修复「点心血管分类出来甲状腺患者」）
-- 背景：批量导入时 department 字段与病例内容大面积错位。
-- 范围：仅 74 个正式 BL 编号病例（case_no IS NOT NULL），逐条按标题/隐藏诊断重标。
-- 6000 个无 case_no 的问答式条目不在此处理（由后端查询过滤退出病例库，数据保留）。
-- 幂等：重复执行无副作用。
USE zhiyu_db;

-- 心血管内科 → 实际科室
UPDATE sp_case_config SET department='消化内科' WHERE case_no='BL000009';  -- 食管疾病 胃食管反流病
UPDATE sp_case_config SET department='内分泌科' WHERE case_no='BL000017';  -- 嗜铬细胞瘤（肾上腺）
UPDATE sp_case_config SET department='急诊科'   WHERE case_no='BL000042';  -- 外科休克 肝胆胰术后失血性休克
UPDATE sp_case_config SET department='综合'     WHERE case_no='BL000063';  -- 全身麻醉术前评估和准备
UPDATE sp_case_config SET department='内分泌科' WHERE case_no='BL000064';  -- 垂体腺瘤
UPDATE sp_case_config SET department='内分泌科' WHERE case_no='BL000067';  -- 肥胖症
UPDATE sp_case_config SET department='泌尿外科' WHERE case_no='BL000076';  -- 勃起功能障碍
UPDATE sp_case_config SET department='普外科'   WHERE case_no='BL000079';  -- 腹部损伤 肝破裂

-- 其他错位
UPDATE sp_case_config SET department='泌尿外科' WHERE case_no='BL000011';  -- 阴茎癌（原综合）
UPDATE sp_case_config SET department='内分泌科' WHERE case_no='BL000012';  -- 甲状旁腺功能亢进（原综合，每日一例引用过）
UPDATE sp_case_config SET department='泌尿外科' WHERE case_no='BL000013';  -- 肾母细胞瘤（原肾内科）
UPDATE sp_case_config SET department='普外科'   WHERE case_no='BL000014';  -- 腹部损伤 脾破裂（原消化内科）
UPDATE sp_case_config SET department='普外科'   WHERE case_no='BL000010';  -- 痔（原综合）
UPDATE sp_case_config SET department='泌尿外科' WHERE case_no='BL000016';  -- 膀胱破裂（原综合）
UPDATE sp_case_config SET department='普外科'   WHERE case_no='BL000018';  -- 脾疾病（原综合）
UPDATE sp_case_config SET department='消化内科' WHERE case_no='BL000019';  -- 食管癌（原综合）
UPDATE sp_case_config SET department='神经内科' WHERE case_no='BL000020';  -- 颅内动静脉畸形（原综合）
UPDATE sp_case_config SET department='骨科'     WHERE case_no='BL000021';  -- 腰椎间盘突出症（原综合）
UPDATE sp_case_config SET department='泌尿外科' WHERE case_no='BL000024';  -- 隐睾癌变（原综合）
UPDATE sp_case_config SET department='泌尿外科' WHERE case_no='BL000027';  -- 肾癌（原肾内科）
UPDATE sp_case_config SET department='普外科'   WHERE case_no='BL000028';  -- 手部急性化脓性感染（原感染科）
UPDATE sp_case_config SET department='泌尿外科' WHERE case_no='BL000031';  -- 压力性尿失禁（原综合）
UPDATE sp_case_config SET department='消化内科' WHERE case_no='BL000032';  -- 短肠综合征（原综合）
UPDATE sp_case_config SET department='消化内科' WHERE case_no='BL000040';  -- 胰腺癌（原综合）
UPDATE sp_case_config SET department='神经内科' WHERE case_no='BL000048';  -- 脑疝（原普外科）
UPDATE sp_case_config SET department='骨科'     WHERE case_no='BL000050';  -- 手外伤及断肢再植（原神经内科）
UPDATE sp_case_config SET department='呼吸内科' WHERE case_no='BL000052';  -- 原发性肺癌（原综合）
UPDATE sp_case_config SET department='泌尿外科' WHERE case_no='BL000055';  -- 睾丸肿瘤（原感染科）
UPDATE sp_case_config SET department='消化内科' WHERE case_no='BL000056';  -- 肝包虫病（原综合）
UPDATE sp_case_config SET department='泌尿外科' WHERE case_no='BL000057';  -- 精索静脉曲张（原综合）
UPDATE sp_case_config SET department='普外科'   WHERE case_no='BL000058';  -- 膈下脓肿（原综合）
UPDATE sp_case_config SET department='普外科'   WHERE case_no='BL000061';  -- 腹腔间隔室综合征（原感染科）
UPDATE sp_case_config SET department='心血管内科' WHERE case_no='BL000062'; -- 主动脉夹层（原骨科！）
UPDATE sp_case_config SET department='内分泌科' WHERE case_no='BL000043';  -- 原发性醛固酮增多症（原综合）
UPDATE sp_case_config SET department='内分泌科' WHERE case_no='BL000065';  -- 胰岛素瘤（原综合）
UPDATE sp_case_config SET department='急诊科'   WHERE case_no='BL000068';  -- 蛇咬伤（原血液科）
UPDATE sp_case_config SET department='普外科'   WHERE case_no='BL000071';  -- 急性乳腺炎（原感染科）
UPDATE sp_case_config SET department='普外科'   WHERE case_no='BL000072';  -- 胃十二指肠溃疡穿孔（原综合）
UPDATE sp_case_config SET department='骨科'     WHERE case_no='BL000073';  -- 骨肿瘤（原血液科）
UPDATE sp_case_config SET department='泌尿外科' WHERE case_no='BL000074';  -- 肾下垂（原肾内科）
UPDATE sp_case_config SET department='普外科'   WHERE case_no='BL000078';  -- ERAS胰十二指肠切除术（原骨科）
UPDATE sp_case_config SET department='普外科'   WHERE case_no='BL000080';  -- 乳腺癌（原综合）
