package com.zhiyu.controller.student;

import com.zhiyu.common.R;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.DailyMrService;
import com.zhiyu.service.dto.DailyMrHintDTO;
import com.zhiyu.service.dto.DailyMrSubmitDTO;
import com.zhiyu.vo.DailyMrBankItemVO;
import com.zhiyu.vo.DailyMrDetailVO;
import com.zhiyu.vo.DailyMrTodayVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * 学生端-每日病历接口（每日一例升级版：九段书写 + AI 教练 + 题库 + 打卡）
 * 路径挂到 /api/v1/student/daily-cases/mr/**，与旧开放作答接口并存
 */
@Tag(name = "学生-每日病历")
@RestController
@RequestMapping("/api/v1/student/daily-cases/mr")
@RequiredArgsConstructor
public class StudentDailyMrController {

    private final DailyMrService dailyMrService;

    @Operation(summary = "今日病历卡（今日排期 + 我的最新记录 + 连续打卡）")
    @GetMapping("/today")
    public R<DailyMrTodayVO> today() {
        return R.ok(dailyMrService.todayMr());
    }

    @Operation(summary = "病历题库（往期列表；done: 不传全部/1已做/0未做）")
    @GetMapping("/bank")
    public R<PageResult<DailyMrBankItemVO>> bank(
            @RequestParam(defaultValue = "1") int pageNum,
            @RequestParam(defaultValue = "20") int pageSize,
            @RequestParam(required = false) Integer done) {
        return R.ok(dailyMrService.bank(pageNum, pageSize, done));
    }

    @Operation(summary = "题目详情（病例材料 + 九段定义 + 我的提交记录；提交过才下发标准答案）")
    @GetMapping("/{scheduleId}")
    public R<DailyMrDetailVO> detail(@PathVariable Long scheduleId) {
        return R.ok(dailyMrService.detail(scheduleId));
    }

    @Operation(summary = "段落教练（AI 三级提示：1追问/2定向提示/3示范片段）")
    @PostMapping("/hint")
    public R<Map<String, Object>> hint(@Valid @RequestBody DailyMrHintDTO dto) {
        return R.ok(dailyMrService.hint(dto));
    }

    @Operation(summary = "提交病历（九段内容 → AI 结构化批阅 → 缺陷沉淀）")
    @PostMapping("/submit")
    public R<Map<String, Object>> submit(@Valid @RequestBody DailyMrSubmitDTO dto) {
        return R.ok(dailyMrService.submit(dto));
    }

    @Operation(summary = "打卡日历（指定年份已提交日期 + 连续天数；不传为今年）")
    @GetMapping("/calendar")
    public R<Map<String, Object>> calendar(@RequestParam(required = false) Integer year) {
        return R.ok(dailyMrService.calendar(year));
    }
}
