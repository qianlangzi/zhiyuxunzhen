package com.zhiyu.common.param;

import lombok.Data;

/**
 * 分页查询参数（PRD 16.3.3）
 */
@Data
public class PageParam {

    /** 页码，从 1 开始 */
    private Integer pageNum = 1;

    /** 每页条数 */
    private Integer pageSize = 10;
}
