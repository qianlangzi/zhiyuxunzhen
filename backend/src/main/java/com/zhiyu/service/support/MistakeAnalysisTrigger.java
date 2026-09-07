package com.zhiyu.service.support;

import com.zhiyu.service.StudentMistakeService;
import jakarta.annotation.Resource;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.util.concurrent.Executor;

/**
 * 错题归因异步预生成触发器。
 *
 * <p>错题入库后自动触发 AI 归因，使学生打开错题本即可看到分叉定位结果，
 * 无需手动点击「AI 归因分析」。
 *
 * <p><b>关键约束：必须等事务提交后再执行。</b>
 * 异步任务跑在独立线程（独立数据库连接），若主事务尚未提交，
 * 异步线程查询刚插入的错题记录会查不到，导致归因静默失败。
 * 因此这里注册 afterCommit 回调；无事务上下文时（如单元测试）退化为直接异步执行。
 */
@Slf4j
@Component
public class MistakeAnalysisTrigger {

    @Resource(name = "aiTaskExecutor")
    private Executor aiTaskExecutor;

    private final StudentMistakeService studentMistakeService;

    public MistakeAnalysisTrigger(StudentMistakeService studentMistakeService) {
        this.studentMistakeService = studentMistakeService;
    }

    /**
     * 触发归因预生成（事务提交后执行，失败只记日志不影响主链路）。
     *
     * @param mistakeId 新入库的错题 id
     * @param studentId 归属学生 id
     */
    public void triggerAfterCommit(Long mistakeId, Long studentId) {
        if (mistakeId == null || studentId == null) {
            return;
        }
        Runnable task = () -> {
            try {
                studentMistakeService.generateAnalysis(mistakeId, studentId);
            } catch (Exception e) {
                log.warn("错题归因异步任务异常: mistakeId={} err={}", mistakeId, e.getMessage());
            }
        };
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    aiTaskExecutor.execute(task);
                }
            });
        } else {
            aiTaskExecutor.execute(task);
        }
    }
}
