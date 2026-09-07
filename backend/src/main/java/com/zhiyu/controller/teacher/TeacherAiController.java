package com.zhiyu.controller.teacher;

import com.zhiyu.common.R;
import com.zhiyu.service.TeacherAiService;
import com.zhiyu.service.dto.CaseDraftDTO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * 教师端 AI 辅助接口（PRD 4.1 / 9.3 扩展）
 *
 * 所有接口返回结构化结果；AI 不可用时返回 message 提示，不影响教师主流程。
 */
@Tag(name = "教师-AI辅助")
@RestController
@RequestMapping("/api/v1/teacher/ai")
@RequiredArgsConstructor
public class TeacherAiController {

    private final TeacherAiService teacherAiService;

    @Operation(summary = "AI 生成 SP 病例草稿")
    @PostMapping("/case-draft")
    public R<Map<String, Object>> caseDraft(@Valid @RequestBody CaseDraftDTO req) {
        Map<String, Object> data = teacherAiService.generateCaseDraft(req);
        if (data == null) {
            return R.fail(500, "AI 暂不可用，请稍后重试或手动填写病例");
        }
        return R.ok(data);
    }

    @Operation(summary = "AI 班级学情洞察")
    @GetMapping("/class-insight")
    public R<Map<String, Object>> classInsight(@RequestParam(required = false) Long classId) {
        Long teacherId = com.zhiyu.common.context.UserContext.requireUserId();
        Map<String, Object> data = teacherAiService.classInsight(teacherId, classId);
        if (data == null) {
            return R.fail(500, "AI 暂不可用，无法生成学情洞察");
        }
        return R.ok(data);
    }

    @Operation(summary = "AI 复核辅助（复核建议 + 评语草稿）")
    @GetMapping("/review-assist/{instanceId}")
    public R<Map<String, Object>> reviewAssist(@PathVariable Long instanceId) {
        Map<String, Object> data = teacherAiService.reviewAssist(instanceId);
        if (data == null) {
            return R.fail(500, "AI 暂不可用，无法生成复核建议");
        }
        return R.ok(data);
    }

    @Operation(summary = "AI 推荐作业病例（按班级薄弱点）")
    @GetMapping("/recommend-cases")
    public R<Map<String, Object>> recommendCases(@RequestParam Long classId) {
        Map<String, Object> data = teacherAiService.recommendCases(classId);
        if (data == null) {
            return R.fail(500, "AI 暂不可用，无法推荐病例");
        }
        return R.ok(data);
    }

    @Operation(summary = "AI 病例质检")
    @GetMapping("/quality-check/{caseId}")
    public R<Map<String, Object>> qualityCheck(@PathVariable Long caseId) {
        Map<String, Object> data = teacherAiService.qualityCheck(caseId);
        if (data == null) {
            return R.fail(500, "AI 暂不可用，无法质检病例");
        }
        return R.ok(data);
    }

    @Operation(summary = "AI 自动生成练习题")
    @GetMapping("/practice-questions/{caseId}")
    public R<Map<String, Object>> practiceQuestions(@PathVariable Long caseId) {
        Map<String, Object> data = teacherAiService.practiceQuestions(caseId);
        if (data == null) {
            return R.fail(500, "AI 暂不可用，无法生成练习题");
        }
        return R.ok(data);
    }

    @Operation(summary = "病例素材智能推荐（AI 建议应准备的多模态材料清单）")
    @GetMapping("/material-advice/{caseId}")
    public R<Map<String, Object>> materialAdvice(@PathVariable Long caseId) {
        Map<String, Object> data = teacherAiService.materialAdvice(caseId);
        if (data == null) {
            return R.fail(500, "AI 暂不可用，无法推荐素材");
        }
        return R.ok(data);
    }

    @Operation(summary = "生成并持久化学情诊断报告（classId 为空=全体学生）")
    @PostMapping("/report/class")
    public R<Map<String, Object>> generateClassReport(
            @RequestParam(required = false) Long classId) {
        return R.ok(teacherAiService.generateClassReport(classId));
    }

    @Operation(summary = "学情诊断报告列表")
    @GetMapping("/reports")
    public R<java.util.List<Map<String, Object>>> listDiagnosisReports() {
        return R.ok(teacherAiService.listDiagnosisReports());
    }

    @Operation(summary = "学情诊断报告详情")
    @GetMapping("/reports/{id}")
    public R<Map<String, Object>> getDiagnosisReport(@PathVariable Long id) {
        return R.ok(teacherAiService.getDiagnosisReport(id));
    }

    @Operation(summary = "删除学情诊断报告")
    @DeleteMapping("/reports/{id}")
    public R<Void> deleteDiagnosisReport(@PathVariable Long id) {
        teacherAiService.deleteDiagnosisReport(id);
        return R.ok();
    }
}