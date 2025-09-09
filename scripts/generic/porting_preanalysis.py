from loki import (
    Sourcefile,
    Loop,
    MaskedStatement,
    CallStatement,
    Intrinsic,
    FindNodes,
    FindVariables,
)

import sys 
import re
import os
from pathlib import Path


# TODO: Fix bug with statement labels: 'Input should be a valid string [type=string_type, input_value=XXX, input_type=int]'
def remove_labels(filename):
    with open(filename, "r") as file:
        source = file.read()
    source = re.sub(r"^\s*\d+\s*(.+)$", r"\1", source, flags=re.MULTILINE)
    return source

if len(sys.argv) < 2:
    print("Usage: python porting_preanalysis.py /PATH/TO/NEMO/TARGET/SRC/")
    sys.exit()

source_path = sys.argv[1]
path = Path(source_path)

for file in path.glob("*.F90"):
    filename = str(file)
    print("Checking: " + filename)
    try:
        source = Sourcefile.from_source(
            remove_labels(filename),
            preprocess=True,
            defines=["key_si3"],
            includes=[os.path.join(path.parent, "OCE")],
        )

        source_data = source.to_fortran()
        if not source.modules:
            print("\tNo modules found in the parsed source.")
        else:
            if not source.modules[0].subroutines:
                print("\tNo subroutines found in the parsed module.")
            else:
                for subroutine in source.modules[0].subroutines:
                    loops = FindNodes(Loop, greedy=False).visit(subroutine.body)
                    outer_loops = []

                    for loop in loops:
                        is_outer = True
                        for other_loop in loops:
                            if loop != other_loop and loop in FindNodes(
                                Loop, greedy=False
                            ).visit(other_loop.body):
                                is_outer = False
                                break

                        if is_outer:
                            outer_loops.append(loop)

                    wheres = FindNodes(MaskedStatement, greedy=False).visit(
                        subroutine.body
                    )
                    calls = FindNodes(CallStatement, greedy=False).visit(
                        subroutine.body
                    )

                    # Filtering non-useful function calls
                    skipping_list = ("timing", "ctl_", "nompinfo", "iom")

                    filtered_calls = [
                        call.name.name
                        for call in calls
                        if not any(skip in call.name.name for skip in skipping_list)
                    ]

                    math_intrinsics = FindVariables(unique=False).visit(subroutine.body)
                    sums = [v.name.lower() for v in math_intrinsics].count("sum")

                    if (
                        len(loops) == 0
                        and len(wheres) == 0
                        and len(filtered_calls) == 0
                        and sums == 0
                    ):
                        print(
                            "\t"
                            + subroutine.name
                            + " doesn't have any interesting statement."
                        )
                    else:
                        print("\t" + subroutine.name)

                    if len(outer_loops) > 0:
                        print(
                            "\t\t"
                            + str(len(outer_loops))
                            + " loops with "
                            + ",".join(
                                str(l.source.lines[1] - l.source.lines[0])
                                for l in outer_loops
                            )
                            + " lines of code."
                        )
                    if sums > 0:
                        print("\t\t" + str(sums) + " SUMs.")
                    if len(wheres) > 0:
                        print("\t\t" + str(len(wheres)) + " wheres.")
                    if len(filtered_calls) > 0:
                        print(
                            "\t\t"
                            + str(len(filtered_calls))
                            + " function/subroutine calls: "
                            + " ".join(list(dict.fromkeys(filtered_calls)))
                        )
    except Exception as err:
        print("\tUnexpected parsing error!")
    print("")
 
