"""Reproducible, offline SGF import. Run with the Python standard library only."""
from __future__ import annotations
import collections
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/problems/gogameguru'
COMMIT = 'eee12b2e39d59dbe81a8b9eaa7d4f103978d9224'


class SGF:
    def __init__(self, text):
        self.text = text.replace('\r\n', '\n').replace('\r', '\n')
        self.i = 0

    def skip(self):
        while self.i < len(self.text) and self.text[self.i].isspace():
            self.i += 1

    def take(self, c):
        self.skip()
        assert self.text[self.i] == c, (self.i, c, self.text[self.i:self.i+40])
        self.i += 1

    def value(self):
        self.take('[')
        out = ''
        while self.i < len(self.text):
            c = self.text[self.i]
            self.i += 1
            if c == ']':
                return out
            if c == '\\':
                c = self.text[self.i]
                self.i += 1
                if c == '\n':
                    continue
            out += c
        raise ValueError('Unterminated SGF value')

    def tree(self):
        self.take('(')
        first = tail = None
        self.skip()
        while self.text[self.i] == ';':
            self.take(';')
            props = {}
            self.skip()
            while self.text[self.i].isalpha():
                start = self.i
                while self.text[self.i].isalpha():
                    self.i += 1
                key = self.text[start:self.i]
                assert key not in props
                values = []
                self.skip()
                while self.text[self.i] == '[':
                    values.append(self.value())
                    self.skip()
                assert values
                props[key] = values
            node = {'props': props, 'children': []}
            if first is None:
                first = node
            else:
                tail['children'].append(node)
            tail = node
        assert tail is not None
        while self.text[self.i] == '(':
            tail['children'].append(self.tree())
            self.skip()
        self.take(')')
        return first

    def parse(self):
        root = self.tree()
        self.skip()
        assert self.i == len(self.text)
        return root


def walk(node):
    yield node
    for child in node['children']:
        yield from walk(child)


def read_sgf(file):
    text = file.read_text(encoding='utf-8-sig')
    # Upstream has one extra closing parenthesis after the complete game tree.
    # Preserve the distributed source byte-for-byte; repair only the parsed copy.
    if file.name == 'ggg-intermediate-50.sgf':
        assert text.endswith(')\n)\n')
        text = text.rstrip()[:-1]
    return SGF(text).parse()


def inspect():
    stats = collections.Counter()
    odd = []
    props = collections.Counter()
    for file in sorted((SOURCE / 'sgf').rglob('*.sgf')):
        root = read_sgf(file)
        nodes = list(walk(root))
        comments = [n['props'].get('C', [''])[0] for n in nodes]
        correct = [c for c in comments if re.match(r'^(?:Also )?Correct\b', c, re.I)]
        stats['files'] += 1
        stats['nodes'] += len(nodes)
        stats['correct_markers'] += len(correct)
        stats['nonleaf_correct'] += sum(bool(n['children']) and bool(re.match(r'^(?:Also )?Correct\b', n['props'].get('C', [''])[0], re.I)) for n in nodes)
        stats['size_'+root['props'].get('SZ', ['19'])[0]] += 1
        for n in nodes:
            props.update(n['props'].keys())
        if not correct:
            odd.append({'file': str(file.relative_to(SOURCE)), 'root': root['props'], 'leaves': [n['props'] for n in nodes if not n['children']]})
    print(json.dumps({'stats': stats, 'props': props, 'no_correct': odd}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    inspect()
