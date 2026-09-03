package com.zhiyu.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.zhiyu.entity.UserPreference;
import org.apache.ibatis.annotations.Mapper;

/**
 * 用户偏好 Mapper（AI 学伴语气 / 记忆开关）
 */
@Mapper
public interface UserPreferenceMapper extends BaseMapper<UserPreference> {
}
