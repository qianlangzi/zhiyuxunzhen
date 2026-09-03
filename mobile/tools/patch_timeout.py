"""为 student_api.dart 中 AI / 耗时接口注入超时 Options。

背景：ApiClient 全局 receiveTimeout 仅 8 秒，而后端这批接口内部同步调用
AI 中台，实际耗时 20~90 秒，不覆盖会稳定抛 receiveTimeout。
"""

import re
import sys

PATH = r'E:\zhiyu\mobile\lib\features\student\data\student_api.dart'

TARGETS = [
    ('submitDailyCase', "'/api/v1/student/daily-cases/submit'", '_aiOptions'),
    ('finishSession', "'/api/v1/student/sessions/$sessionId/finish'", '_aiOptions'),
    ('retrySessionArchive', "'/api/v1/student/sessions/$sessionId/archive/retry'", '_aiOptions'),
    ('exportReport', "'/api/v1/student/review-report/export'", '_mediumOptions'),
    ('analyzeMistake', "'/api/v1/student/mistakes/$id/analyze'", '_aiOptions'),
    ('generateLearningPath', "'/api/v1/student/learning-path/generate'", '_aiOptions'),
    ('generatePaper', "'/api/v1/student/paper/generate'", '_aiOptions'),
    ('sendMessage', "'/api/v1/student/sessions/$sessionId/chat'", '_aiOptions'),
    ('uploadImage', "'/api/v1/student/sessions/$sessionId/image',", '_uploadOptions'),
    ('analyzeImage', "'/api/v1/student/sessions/$sessionId/image/analyze'", '_aiOptions'),
    ('submitQuestion', "'/api/v1/student/questions/submit'", '_mediumOptions'),
    ('getRecommendation', "'/api/v1/student/recommend/weakness',", '_aiOptions'),
    ('searchResources', "'/api/v1/student/recommend/search'", '_mediumOptions'),
    ('searchKnowledgeByImage', "'/api/v1/knowledge/search-image'", '_aiOptions'),
    ('getAiDiagnosis', "'/api/v1/student/recommend/diagnosis'", '_aiOptions'),
    ('submitPaperTask', "'/api/v1/student/paper/tasks',", '_mediumOptions'),
    ('getPaperTask', "'/api/v1/student/paper/tasks/$taskId'", '_mediumOptions'),
]


def find_method(lines, name):
    pat = re.compile(r'\b' + re.escape(name) + r'\(')
    for i, line in enumerate(lines):
        if line.lstrip().startswith('Future') and pat.search(line):
            return i
    return None


def main():
    with open(PATH, encoding='utf-8') as fh:
        lines = fh.read().split('\n')

    ok, fail = 0, []
    for name, frag, opt in TARGETS:
        mstart = find_method(lines, name)
        if mstart is None:
            fail.append((name, 'method not found'))
            continue

        frag_line = None
        for j in range(mstart, min(mstart + 90, len(lines))):
            if frag in lines[j]:
                frag_line = j
                break
        if frag_line is None:
            fail.append((name, 'url not found'))
            continue

        ci = frag_line
        if '_dio.' not in lines[ci]:
            for k in range(frag_line, max(mstart - 1, -1), -1):
                if '_dio.' in lines[k]:
                    ci = k
                    break
            else:
                fail.append((name, 'dio call not found'))
                continue

        if 'options:' in lines[ci]:
            ok += 1
            continue

        stripped = lines[ci].rstrip()
        if stripped.endswith(');'):
            idx = stripped.rfind(');')
            lines[ci] = stripped[:idx] + ', options: ' + opt + ');'
            ok += 1
        else:
            closed = None
            for k in range(ci + 1, min(ci + 45, len(lines))):
                if re.match(r'^\s*\);\s*$', lines[k]):
                    closed = k
                    break
            if closed is None:
                fail.append((name, 'closing paren not found'))
                continue
            lines.insert(closed, '        options: ' + opt + ',')
            ok += 1

    with open(PATH, 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(lines))

    print('patched: %d' % ok)
    for name, why in fail:
        print('FAILED  %-24s %s' % (name, why))
    return 0 if not fail else 1


if __name__ == '__main__':
    sys.exit(main())
