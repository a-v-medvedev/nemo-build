import sys
import re
import math

def parse_md_table(md: str):
    lines = [line.strip() for line in md.strip().splitlines() if line.strip()]
    if len(lines) < 2:
        raise ValueError("Not a valid markdown table")

    headers = [h.strip() for h in lines[0].strip("|").split("|")]
    if re.match(r'^\s*\|?[-: ]+\|', lines[1]):
        data_lines = lines[2:]
    else:
        data_lines = lines[1:]
    rows = [headers]
    for line in data_lines:
        cols = [c.strip() for c in line.strip("|").split("|")]
        rows.append(cols)
    return rows

def md_to_svg(md: str, font_size=16, padding_x=10, padding_y=6):
    rows = parse_md_table(md)

    def text_width(s, size):
        return len(s) * size * 0.7

    ncols = max(len(r) for r in rows)
    col_widths = [0] * ncols

    # compute max width per column with appropriate font size
    for ridx, r in enumerate(rows):
        fsize = font_size + 2 if ridx == 0 else font_size
        for i, cell in enumerate(r):
            w = text_width(cell, fsize) + 2 * padding_x
            col_widths[i] = max(col_widths[i], w)

    row_heights = []
    for ridx, _ in enumerate(rows):
        fsize = font_size + 2 if ridx == 0 else font_size
        row_heights.append(fsize + 2 * padding_y)

    table_width = sum(col_widths)
    table_height = sum(row_heights)

    svg = []
    svg.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{math.ceil(table_width)}" height="{math.ceil(table_height)}">')
    svg.append(f'<rect x="2" y="2" width="{math.ceil(table_width)-4}" height="{math.ceil(table_height)-4}" fill="white" stroke="black" stroke-width="2"/>')

    y = 0
    for row_idx, row in enumerate(rows):
        x = 0
        fsize = font_size + 2 if row_idx == 0 else font_size
        row_height = row_heights[row_idx]
        for col in range(ncols):
            w = col_widths[col]
            fill = "lightgray" if row_idx == 0 else "none"
            svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{row_height}" fill="{fill}" stroke="black" stroke-width="2"/>')
            if col < len(row):
                text = row[col]

                # detect bold
                bold_match = re.match(r'^\*\*(.*?)\*\*$', text)
                if bold_match:
                    text = bold_match.group(1)
                    weight = "bold"
                else:
                    weight = "normal"

                # detect monospace (backticks)
                mono_match = re.match(r'^`(.*?)`$', text)
                if mono_match:
                    text = mono_match.group(1)
                    family = "monospace"
                else:
                    family = "sans-serif"

                tx = x + padding_x
                ty = y + padding_y + fsize * 0.8
                if row_idx == 0:
                    ty = ty + 1
                svg.append(
                    f'<text x="{tx}" y="{ty}" font-weight="{weight}" font-family="{family}" font-size="{fsize}px">{text}</text>'
                )
            x += w
        y += row_height

    svg.append(f'<rect x="2" y="2" width="{math.ceil(table_width)-4}" height="{math.ceil(table_height)-4}" fill="none" stroke="black" stroke-width="2"/>')
    svg.append('</svg>')
    return "\n".join(svg)

if __name__ == "__main__":
    md = sys.stdin.read()
    print(md_to_svg(md))
