"""Offline conversion of the pinned Go Game Guru source; stdlib only.

Generated content retains the source CC BY-NC-SA 4.0 license.
"""
import collections
import hashlib
import json
import re
from import_problems import ROOT, SOURCE, COMMIT, read_sgf


def point(value, size):
    if value == '' or value == 'tt' and size <= 19:
        return -1
    assert len(value) == 2, value
    x, y = [ord(v) - ord('a') for v in value]
    assert 0 <= x < size and 0 <= y < size, value
    return y * size + x


def neighbors(p, size):
    x, y = p % size, p // size
    return [yy * size + xx for xx, yy in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)) if 0 <= xx < size and 0 <= yy < size]


def group(board, p, size):
    stones, liberties, stack = {p}, set(), [p]
    while stack:
        for q in neighbors(stack.pop(), size):
            if board[q] == 0:
                liberties.add(q)
            elif board[q] == board[p] and q not in stones:
                stones.add(q)
                stack.append(q)
    return stones, liberties


def play(board, p, color, size, history):
    if p < 0:
        return board.copy(), ''
    if board[p]:
        return None, 'occupied'
    after = board.copy()
    after[p] = color
    for q in neighbors(p, size):
        if after[q] == 3-color:
            stones, liberties = group(after, q, size)
            if not liberties:
                for stone in stones:
                    after[stone] = 0
    if not group(after, p, size)[1]:
        return None, 'suicide'
    if tuple(after) in history:
        return None, 'repetition'
    return after, ''


ROOT_TEXT = {
    'ggg-easy-28': '找到吃住两颗白子的办法。',
    'ggg-easy-41': '设法吃住标记 A 处的白棋断子。',
    'ggg-easy-48': '白棋 A 本应下在 B。黑棋如何利用这个失误？',
    'ggg-easy-49': '既要防住白棋在 A 提子，又要赢得 B、C 两块棋的对杀。',
    'ggg-easy-81': '想办法把黑棋全部连接起来。',
    'ggg-easy-99': '找到吃住白棋断子的办法。',
    'ggg-hard-39': '白棋刚刚落在 A，黑棋如何应对？',
    'ggg-hard-56': '本题取自职业混双棋局。黑棋应如何下？',
    'ggg-hard-73': '想办法利用标记 A 处的黑子。',
    'ggg-hard-78': '白棋 A 若下在 B，黑棋会死。现在黑棋有何机会？',
    'ggg-intermediate-28': '黑棋如何应对白棋 A？',
    'ggg-intermediate-36': '白棋 A 是过分的一手，黑棋如何反击？',
    'ggg-intermediate-42': '白棋 A 是过分的一手，黑棋如何反击？',
    'ggg-intermediate-38': '黑棋如何抵抗白棋 A？',
    'ggg-intermediate-43': '白棋 A 是失误，黑棋如何利用？',
    'ggg-intermediate-45': '黑棋如何利用 A 处的棋子？',
    'ggg-intermediate-65': '黑棋如何攻击白棋 A？',
    'ggg-intermediate-68': '白棋刚在 A 分断黑棋，如何破坏白棋的计划？',
    'ggg-intermediate-81': '黑棋如何防守白棋 A？',
}


def compile_problem(file, issues):
    root = read_sgf(file)
    props = root['props']
    size = int(props['SZ'][0])
    board = [0] * (size * size)
    for prop, color in [('AB', 1), ('AW', 2)]:
        for coord in props.get(prop, []):
            p = point(coord, size)
            assert p >= 0 and board[p] == 0
            board[p] = color
    assert all(group(board, p, size)[1] for p in range(len(board)) if board[p]), file.name
    nodes = []

    def flatten(source):
        p = source['props']
        idx = len(nodes)
        color = 1 if 'B' in p else (2 if 'W' in p else 0)
        comment = p.get('C', [''])[0].strip()
        labels = {str(point(s.split(':', 1)[0], size)): s.split(':', 1)[1] for s in p.get('LB', [])}
        labels.update({str(point(s, size)): '△' for s in p.get('TR', [])})
        node = {'point': point(p['B' if color == 1 else 'W'][0], size) if color else -2,
                'color': color, 'children': [], 'comment': comment, 'labels': labels,
                'correct': bool(re.match(r'^(?:Also )?Correct\b', comment, re.I))}
        nodes.append(node)
        node['children'] = [flatten(child) for child in source['children']]
        node['good'] = node['correct'] or any(nodes[c]['good'] for c in node['children'])
        return idx

    flatten(root)
    assert nodes[0]['color'] == 0 and nodes[0]['children']
    turn = nodes[nodes[0]['children'][0]]['color']
    assert turn == 1
    bad_edges = []

    def validate(idx, cells, color, history, path):
        for c in nodes[idx]['children'][:]:
            node = nodes[c]
            assert node['color'] != 0, (file.name, c)
            after, error = play(cells, node['point'], node['color'], size, history)
            if node['color'] != color:
                error = 'nonalternating'
            if error:
                bad_edges.append({'parent': idx, 'node': c, 'reason': error, 'path': path + [c], 'contains_correct': node['good']})
                nodes[idx]['children'].remove(c)
            else:
                validate(c, after, 3-color, history | {tuple(after)}, path + [c])
        nodes[idx]['good'] = nodes[idx]['correct'] or any(nodes[c]['good'] for c in nodes[idx]['children'])

    validate(0, board, turn, {tuple(board)}, [])
    if bad_edges:
        issues.append({'id': file.stem, 'excluded_branches': bad_edges})
    reachable = []
    def visit(i):
        reachable.append(i)
        for c in nodes[i]['children']:
            visit(c)
    visit(0)
    mapping = {old: new for new, old in enumerate(reachable)}
    nodes = [{**nodes[i], 'children': [mapping[c] for c in nodes[i]['children']]} for i in reachable]
    assert nodes[0]['good'], f'No playable annotated solution: {file.name}'
    category = file.parent.name
    level = {'easy': '初级', 'intermediate': '中级', 'hard': '高级'}[category]
    number = int(file.stem.rsplit('-', 1)[1])
    occupied = [p for p, v in enumerate(board) if v]
    occupied += [n['point'] for n in nodes if n['point'] >= 0]
    occupied += [int(p) for n in nodes for p in n['labels']]
    bounds = [min(p % size for p in occupied), min(p // size for p in occupied), max(p % size for p in occupied), max(p // size for p in occupied)]
    return {
        'id': f'ggg-{category}-{number:03d}', 'title': f'GGG · {level} {number:03d}',
        'type': '死活与手筋', 'difficulty': category, 'level': level,
        'size': size, 'board': board, 'turn': turn,
        'text': ROOT_TEXT.get(file.stem, '读清局部的气、眼与连接，找出黑棋的最佳手段。') + '\n\n按原题解连续作答，白棋自动应手。',
        'goal': '黑先 · 读棋', 'nodes': nodes, 'focus': bounds,
        'answer': [nodes[c]['point'] for c in nodes[0]['children'] if nodes[c]['good']],
        'hint': '先观察双方的气、眼形和断点，再比较候选着手。需要落点提示时点“查看落点”。',
        'explain': '已走到原题标注的正确结论。可重做以练习其他应手，或查看原题评注。',
        'source': 'Go Game Guru', 'source_path': file.relative_to(SOURCE).as_posix(),
        'source_url': f'https://github.com/gogameguru/go-problems/blob/{COMMIT}/weekly-go-problems/{category}/{file.name}',
        'source_sha256': hashlib.sha256(file.read_bytes()).hexdigest(), 'license': 'CC BY-NC-SA 4.0',
    }


def build():
    # Compare every downloaded SGF with the pinned Git object inventory.
    # SHA-1 is used here only as Git's object identifier, alongside SHA-256 below.
    tree = json.loads((SOURCE / 'tree.json').read_text(encoding='utf-8-sig'))
    objects = {entry['path']: entry for entry in tree['tree'] if entry['type'] == 'blob'}
    verified = 0
    for file in (SOURCE / 'sgf').rglob('*.sgf'):
        payload = file.read_bytes()
        source_path = 'weekly-go-problems/' + file.relative_to(SOURCE / 'sgf').as_posix()
        blob = hashlib.sha1(f'blob {len(payload)}\0'.encode() + payload).hexdigest()
        assert blob == objects[source_path]['sha'], f'Source differs from pinned commit: {file.name}'
        verified += 1
    issues = []
    puzzles = []
    for category in ['easy', 'intermediate', 'hard']:
        files = sorted((SOURCE / 'sgf' / category).glob('*.sgf'), key=lambda f: int(f.stem.rsplit('-', 1)[1]))
        puzzles.extend(compile_problem(f, issues) for f in files)
    output = {'version': 1, 'source_commit': COMMIT, 'license': 'CC BY-NC-SA 4.0', 'puzzles': puzzles}
    destination = ROOT / 'assets/problems/library.json'
    destination.write_text(json.dumps(output, ensure_ascii=False, separators=(',', ':')) + '\n', encoding='utf-8')
    report = {'source_commit': COMMIT, 'verified_source_files': verified, 'puzzles': len(puzzles), 'nodes': sum(len(p['nodes']) for p in puzzles),
              'correct_conclusions': sum(sum(n['correct'] for n in p['nodes']) for p in puzzles),
              'difficulty': dict(collections.Counter(p['difficulty'] for p in puzzles)),
              'syntax_repairs': [{'file': 'ggg-intermediate-50.sgf', 'change': 'Ignore one extraneous final closing parenthesis in parsed copy; original SGF unchanged.'}],
              'excluded_files': ['other/ggg-eternal-life.sgf (cyclic rules demonstration)', 'other/heart-go-problem.sgf (no explicit correct marker)'],
              'excluded_branches': issues,
              'library_sha256': hashlib.sha256(destination.read_bytes()).hexdigest()}
    (ROOT / 'evidence/puzzle-import.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    build()
