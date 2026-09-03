package com.zhiyu.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.zhiyu.entity.UserActionLog;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface UserActionLogMapper extends BaseMapper<UserActionLog> {
}
