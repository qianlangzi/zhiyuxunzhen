"""修复批量替换强调色后残留的 const 上下文冲突。

kernel 编译器要求 const 构造内只能是编译期常量，AppColors.xxxOf(context)
是运行时方法调用，会报 "Not a constant expression"。
本脚本按报错行定位，去掉所属 const 构造的 const 关键字（改为运行时构造，
只损失少量性能，语义不变）。
"""

import re
import subprocess
import sys

# file -> [报错行号]（来自 flutter build 的 kernel 编译错误输出）
ERRORS = {
    'lib/features/auth/presentation/login_screen.dart': [500],
    'lib/features/auth/presentation/register_screen.dart': [589, 673],
    'lib/features/auth/presentation/forgot_password_screen.dart': [284],
    'lib/features/student/market/student_case_market_screen.dart': [297],
    'lib/features/student/chat/chat_room_screen.dart': [
        664, 670, 987, 1147, 1260, 1402, 1466, 1949, 2027, 2033, 2120,
    ],
    'lib/features/student/archive/learning_archive_screen.dart': [318],
    'lib/features/student/feedback/feedback_screen.dart': [319],
    'lib/features/common/profile/profile_edit_screen.dart': [346, 411],
    'lib/features/teacher/home/teacher_home_screen.dart': [262, 272, 307],
    'lib/features/teacher/market/case_market_screen.dart': [440],
    'lib/features/teacher/review/essay_review_screen.dart': [702, 707],
    'lib/features/teacher/dashboard/dashboard_screen.dart': [543],
    'lib/features/auth/presentation/widgets/auth_field.dart': [61],
    'lib/features/auth/presentation/widgets/captcha_widget.dart': [
        111, 161, 169, 211,
    ],
}

ROOT = r'E:\zhiyu\mobile'


def read_lines(path):
    with open(path, encoding='utf-8') as fh:
        return fh.read().split('\n')


def write_lines(path, lines):
    with open(path, 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(lines))


def balance(line):
    return line.count('(') - line.count(')')


def strip_const(lines, idx):
    lines[idx] = lines[idx].replace('const ', '')


def fix(path, errline):
    lines = read_lines(path)
    idx = errline - 1
    if idx >= len(lines):
        return 'OUT-OF-RANGE'
    if 'const ' in lines[idx]:
        strip_const(lines, idx)
        write_lines(path, lines)
        return 'inline'
    for j in range(idx - 1, max(idx - 11, -1), -1):
        txt = lines[j]
        if 'const ' not in txt:
            continue
        if ' = ' in txt or balance(txt) != 0:
            strip_const(lines, j)
            write_lines(path, lines)
            return 'ancestor@%d' % (j + 1)
    return 'UNRESOLVED'


def main():
    unresolved = []
    for rel, linenos in ERRORS.items():
        path = ROOT + '\\' + rel.replace('/', '\\')
        for n in sorted(linenos):
            r = fix(path, n)
            print('%-70s L%-5d %s' % (rel, n, r))
            if r == 'UNRESOLVED':
                unresolved.append((rel, n))
    print('\nunresolved: %d' % len(unresolved))
    return 1 if unresolved else 0


if __name__ == '__main__':
    sys.exit(main())
