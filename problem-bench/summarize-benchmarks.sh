#!/bin/sh

#: Summarizes recorded benchmark results for quick comparison.

set -eu

LC_ALL=C
export LC_ALL

if [ "$#" -gt 1 ]; then
    echo "usage: $0 [results-directory]" >&2
    exit 2
fi

results_root=${1:-bench-results}

if [ ! -d "$results_root" ]; then
    echo "results directory does not exist: $results_root" >&2
    exit 1
fi

metadata_count=$(find "$results_root" -type f -name metadata.txt | wc -l)
if [ "$metadata_count" -eq 0 ]; then
    echo "no benchmark results found under $results_root" >&2
    exit 1
fi

printf '%-51s %-12s %-9s %-24s %9s %9s\n' \
    RUN LABEL COMMIT WORKLOAD MEDIAN PEAK_MIB

find "$results_root" -type f -name metadata.txt | sort | while IFS= read -r metadata; do
    results_dir=${metadata%/metadata.txt}
    set -- "$results_dir"/*.json
    if [ ! -e "$1" ]; then
        echo "no benchmark results found under $results_dir" >&2
        exit 1
    fi

    measurements=$(
        for result in "$results_dir"/*.json; do
            workload=${result##*/}
            workload=${workload%.json}
            values=$(jq -er '
                .results[0] as $result
                | if (.results | length) != 1 then
                    error("expected exactly one benchmark result")
                elif ($result.exit_codes | length) == 0
                    or any($result.exit_codes[]; . != 0) then
                    error("benchmark command did not complete successfully")
                elif ($result.memory_usage_byte | length) == 0 then
                    error("benchmark result has no memory measurements")
                else
                    [$result.median, (($result.memory_usage_byte | max) / 1048576)]
                    | @tsv
                end
            ' "$result")
            printf '%s\t%s\n' "$workload" "$values"
        done
    )

    hostname=$(awk -F= '$1 == "hostname" { sub(/^[^=]*=/, ""); print; exit }' "$metadata")
    label=$(awk -F= '$1 == "label" { sub(/^[^=]*=/, ""); print; exit }' "$metadata")
    commit=$(awk -F= '$1 == "git_commit" { sub(/^[^=]*=/, ""); print; exit }' "$metadata")
    dirty=$(awk -F= '$1 == "git_dirty" { sub(/^[^=]*=/, ""); print; exit }' "$metadata")
    run=$hostname/${results_dir##*/}
    label=${label:--}
    commit=$(printf '%.8s' "$commit")

    if [ "$dirty" = true ]; then
        commit=$commit+
    fi

    tab=$(printf '\t')
    printf '%s\n' "$measurements" | while IFS="$tab" read -r workload median peak_mib; do
        printf '%-51s %-12s %-9s %-24s %8.3fs %9.1f\n' \
            "$run" "$label" "$commit" "$workload" "$median" "$peak_mib"
    done

    totals=$(printf '%s\n' "$measurements" | awk -F '\t' '
        {
            total += $2
            if ($3 > peak) peak = $3
        }
        END { printf "%.9f\t%.9f", total, peak }
    ')
    IFS="$tab" read -r total peak_mib <<EOF
$totals
EOF
    printf '%-51s %-12s %-9s %-24s %8.3fs %9.1f\n' \
        "$run" "$label" "$commit" TOTAL "$total" "$peak_mib"
done
