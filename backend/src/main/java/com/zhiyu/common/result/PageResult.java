package com.zhiyu.common.result;

import com.baomidou.mybatisplus.core.metadata.IPage;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * 分页响应体（PRD 16.3.3）
 */
@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class PageResult<T> {
    private List<T> list;
    private long total;
    private int page;
    private int pageSize;

    public static <T> PageResult<T> of(IPage<T> p) {
        return PageResult.<T>builder()
                .list(p.getRecords())
                .total(p.getTotal())
                .page((int) p.getCurrent())
                .pageSize((int) p.getSize())
                .build();
    }

    public static <T> PageResult<T> of(List<T> list, long total, int page, int pageSize) {
        return PageResult.<T>builder()
                .list(list)
                .total(total)
                .page(page)
                .pageSize(pageSize)
                .build();
    }

    public static <S, T> PageResult<T> of(IPage<S> p, List<T> list) {
        return PageResult.<T>builder()
                .list(list)
                .total(p.getTotal())
                .page((int) p.getCurrent())
                .pageSize((int) p.getSize())
                .build();
    }
}
