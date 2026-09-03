package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.entity.CompanionMemory;
import com.zhiyu.entity.SysUser;
import com.zhiyu.mapper.CompanionMemoryMapper;
import com.zhiyu.mapper.SysUserMapper;
import com.zhiyu.service.CompanionMemoryService;
import com.zhiyu.service.dto.internal.CompanionMemoriesSyncDTO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * AI 学伴长期记忆服务实现
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class CompanionMemoryServiceImpl implements CompanionMemoryService {

    /** 精确去重窗口：与该生最近 N 条已存记忆比对，内容完全一致的跳过 */
    private static final int DEDUP_WINDOW = 2000;

    private final CompanionMemoryMapper memoryMapper;
    private final SysUserMapper sysUserMapper;

    @Override
    public List<CompanionMemory> recent(int limit) {
        Long studentId = UserContext.requireUserId();
        List<CompanionMemory> rows = memoryMapper.selectList(
                new LambdaQueryWrapper<CompanionMemory>()
                        .eq(CompanionMemory::getStudentId, studentId)
                        .eq(CompanionMemory::getDeleted, 0)
                        .orderByDesc(CompanionMemory::getId)
                        .last("LIMIT " + Math.max(1, limit)));
        Collections.reverse(rows); // 时间正序，最新在最后
        return rows;
    }

    @Override
    public PageResult<CompanionMemory> page(int pageNum, int pageSize) {
        Long studentId = UserContext.requireUserId();
        Page<CompanionMemory> page = new Page<>(pageNum, pageSize);
        memoryMapper.selectPage(page, new LambdaQueryWrapper<CompanionMemory>()
                .eq(CompanionMemory::getStudentId, studentId)
                .eq(CompanionMemory::getDeleted, 0)
                .orderByDesc(CompanionMemory::getId));
        return PageResult.of(page);
    }

    @Override
    public void deleteOwned(Long id) {
        Long studentId = UserContext.requireUserId();
        CompanionMemory memory = memoryMapper.selectById(id);
        if (memory == null || !studentId.equals(memory.getStudentId())
                || Integer.valueOf(1).equals(memory.getDeleted())) {
            throw new BizException(ResultCode.NOT_FOUND, "记忆不存在");
        }
        memory.setDeleted(1);
        memoryMapper.updateById(memory);
    }

    @Override
    public void clearAll() {
        Long studentId = UserContext.requireUserId();
        memoryMapper.update(null, new LambdaUpdateWrapper<CompanionMemory>()
                .eq(CompanionMemory::getStudentId, studentId)
                .eq(CompanionMemory::getDeleted, 0)
                .set(CompanionMemory::getDeleted, 1));
    }

    @Override
    public int saveFromAi(Long studentId, List<CompanionMemoriesSyncDTO.MemoryFact> facts) {
        if (studentId == null || facts == null || facts.isEmpty()) {
            return 0;
        }
        // 归属闸门：内部回调的 studentId 来自 AI 请求体（X-Internal-Token 鉴权链路），
        // 不代表已登录用户，须校验其对应真实在册学生（role=0，逻辑删除记录 selectById 自动过滤），
        // 防止伪造/越权把记忆写入他人名下；不通过则整批拒绝并告警。
        SysUser owner = sysUserMapper.selectById(studentId);
        if (owner == null || !Integer.valueOf(0).equals(owner.getRole())) {
            log.warn("companion_memory_reject_invalid_student: studentId={}", studentId);
            return 0;
        }
        // 精确去重：与该生最近 DEDUP_WINDOW 条已存记忆内容完全一致的跳过。
        // 窗口覆盖正常活跃期的全部记忆；重复事实几乎都发生在近期窗口内，无需全表比对。
        Set<String> existing = memoryMapper.selectList(
                        new LambdaQueryWrapper<CompanionMemory>()
                                .eq(CompanionMemory::getStudentId, studentId)
                                .eq(CompanionMemory::getDeleted, 0)
                                .orderByDesc(CompanionMemory::getId)
                                .last("LIMIT " + DEDUP_WINDOW))
                .stream().map(CompanionMemory::getContent).collect(Collectors.toSet());
        existing = new HashSet<>(existing);

        int saved = 0;
        for (CompanionMemoriesSyncDTO.MemoryFact fact : facts) {
            String content = fact.getContent() == null ? "" : fact.getContent().trim();
            if (content.isEmpty() || content.length() > 500 || existing.contains(content)) {
                continue;
            }
            CompanionMemory memory = new CompanionMemory();
            memory.setStudentId(studentId);
            String factType = fact.getFactType() == null ? "" : fact.getFactType().trim();
            memory.setFactType(factType.isEmpty() ? "fact" : factType.substring(0, Math.min(32, factType.length())));
            memory.setContent(content);
            memory.setSourceSessionId(fact.getSourceSessionId());
            memory.setDeleted(0);
            memoryMapper.insert(memory);
            existing.add(content);
            saved++;
        }
        return saved;
    }
}
