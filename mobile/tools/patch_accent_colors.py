"""把直接引用的静态强调色改为按亮度自适应的语义色。

AppColors.amber / indigo / vermilion / moss3 是 static const，深色模式下
对比度不足。替换为 AppColors.amberOf(context) 等。
仅替换 lib/features 与 lib/shared 下的页面/组件文件，不动 app_colors.dart。
"""

import os
import re
import sys

ROOT = r'E:\zhiyu\mobile\lib'
MAPPING = [
    ('AppColors.amber', 'AppColors.amberOf(context)'),
    ('AppColors.indigo', 'AppColors.indigoOf(context)'),
    ('AppColors.vermilion', 'AppColors.vermilionOf(context)'),
    ('AppColors.moss3', 'AppColors.moss3Of(context)'),
]
PATTERNS = [(re.compile(r'\b' + re.escape(old) + r'\b'), new)
            for old, new in MAPPING]

SKIP = {'app_colors.dart', 'theme_preset.dart'}


def main():
    changed, skipped = 0, 0
    for base in ('features', 'shared'):
        d = os.path.join(ROOT, base)
        for dirpath, _, filenames in os.walk(d):
            for fn in filenames:
                if not fn.endswith('.dart') or fn in SKIP:
                    continue
                p = os.path.join(dirpath, fn)
                with open(p, encoding='utf-8') as fh:
                    src = fh.read()
                out = src
                for pat, new in PATTERNS:
                    out = pat.sub(new, out)
                if out != src:
                    with open(p, 'w', encoding='utf-8') as fh:
                        fh.write(out)
                    changed += 1
                    print('patched  %s' % os.path.relpath(p, ROOT))
                else:
                    skipped += 1
    print('\nchanged files: %d, untouched: %d' % (changed, skipped))
    return 0


if __name__ == '__main__':
    sys.exit(main())
