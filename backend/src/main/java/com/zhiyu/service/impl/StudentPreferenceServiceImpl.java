package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.entity.UserPreference;
import com.zhiyu.mapper.UserPreferenceMapper;
import com.zhiyu.service.StudentPreferenceService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * AI 学伴用户偏好服务实现
 */
@Service
@RequiredArgsConstructor
public class StudentPreferenceServiceImpl implements StudentPreferenceService {

    private final UserPreferenceMapper preferenceMapper;

    @Override
    public Map<String, Object> current() {
        Long studentId = UserContext.requireUserId();
        List<UserPreference> rows = preferenceMapper.selectList(
                new LambdaQueryWrapper<UserPreference>()
                        .eq(UserPreference::getStudentId, studentId)
                        .eq(UserPreference::getIsActive, 1));
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("aiTone", DEFAULT_TONE);
        result.put("aiMemoryEnabled", true);
        for (UserPreference row : rows) {
            if (KEY_TONE.equals(row.getPrefKey())) {
                result.put("aiTone", row.getPrefValue());
            } else if (KEY_MEMORY_ENABLED.equals(row.getPrefKey())) {
                result.put("aiMemoryEnabled", Boolean.parseBoolean(row.getPrefValue()));
            }
        }
        return result;
    }

    @Override
    public void update(String tone, Boolean memoryEnabled) {
        Long studentId = UserContext.requireUserId();
        if (tone != null) {
            if (!SUPPORTED_TONES.contains(tone)) {
                throw new BizException(ResultCode.BAD_REQUEST, "不支持的语气档位");
            }
            upsert(studentId, KEY_TONE, tone);
        }
        if (memoryEnabled != null) {
            upsert(studentId, KEY_MEMORY_ENABLED, String.valueOf(memoryEnabled));
        }
    }

    private void upsert(Long studentId, String key, String value) {
        UserPreference row = preferenceMapper.selectOne(
                new LambdaQueryWrapper<UserPreference>()
                        .eq(UserPreference::getStudentId, studentId)
                        .eq(UserPreference::getPrefKey, key));
        if (row == null) {
            row = new UserPreference();
            row.setStudentId(studentId);
            row.setPrefKey(key);
            row.setPrefValue(value);
            row.setIsActive(1);
            preferenceMapper.insert(row);
        } else {
            row.setPrefValue(value);
            row.setIsActive(1);
            preferenceMapper.updateById(row);
        }
    }
}
