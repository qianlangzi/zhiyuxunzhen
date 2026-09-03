package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotEmpty;
import lombok.Data;

import java.util.List;

/**
 * 批量操作用户 ID 列表（冻结/解冻）
 */
@Data
public class BatchUserIdsDTO {

    @NotEmpty(message = "用户 ID 列表不能为空")
    private List<Long> userIds;
}
