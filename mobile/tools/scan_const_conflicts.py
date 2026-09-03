"""全量扫描：找出跨行 const 构造中包含 Of(context) 运行时调用的残留。

dart analyzer 对部分 const 求值错误不报，但 kernel 编译（flutter build /
flutter run）会直接失败。本脚本模拟括号平衡追踪，覆盖：
  const Foo( ... )   /   const [ ... ]   /   const { ... }
"""

import os
import re
import sys

ROOT = r'E:\zhiyu\mobile\lib'
START = re.compile(r'\bconst\s*(\w+)?\s*([\(\[\{])?')


def balance(line):
    """净括号深度（圆/方/花统一计数）。"""
    return line.count('(') - line.count(')') \
        + line.count('[') - line.count(']') \
        + line.count('{') - line.count('}')


def main():
    suspects = []
    for dirpath, _, filenames in os.walk(ROOT):
        for fn in filenames:
            if not fn.endswith('.dart'):
                continue
            path = os.path.join(dirpath, fn)
            with open(path, encoding='utf-8') as fh:
                lines = fh.read().split('\n')
            i = 0
            while i < len(lines):
                line = lines[i]
                stripped = line.strip()
                # 跳过注释与字符串字面量中的干扰（粗略：行含 // 时截断）
                code = line.split('//')[0]
                m = re.search(r'\bconst\s*[\(\[\{]', code) or \
                    re.search(r'\bconst\s+[A-Z]\w*\s*\(', code) or \
                    re.search(r'\bconst\s+\w+\s*=', code)
                if m:
                    open_b = sum(code.count(c) for c in '([{')
                    close_b = sum(code.count(c) for c in ')]}')
                    depth = open_b - close_b
                    if depth > 0:
                        # 跨行 const 构造：向下追踪直到闭合
                        j = i + 1
                        while j < len(lines) and depth > 0:
                            body = lines[j].split('//')[0]
                            if 'Of(context)' in body or 'Of(ctx)' in body:
                                suspects.append(
                                    '%s:%d (const 起始 L%d)'
                                    % (os.path.relpath(path, ROOT), j + 1, i + 1))
                            depth += sum(body.count(c) for c in '([{') \
                                - sum(body.count(c) for c in ')]}')
                            j += 1
                        i = j
                        continue
                    elif depth == 0 and 'Of(context)' in code:
                        suspects.append(
                            '%s:%d (单行 const)'
                            % (os.path.relpath(path, ROOT), i + 1))
                i += 1
    if suspects:
        print('发现 %d 处 const 上下文中的运行时调用：' % len(suspects))
        for s in suspects:
            print(' ', s)
    else:
        print('OK：未发现 const 构造内的 Of(context) 调用。')
    return 0


if __name__ == '__main__':
    sys.exit(main())
