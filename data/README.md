# Data

The input workbook is not included in this repository.

To run the analysis, save the workbook as `data/nhl_salaries.xlsx`. The script reads the
sheet named `Data Set w Income Tax` and uses its first six columns, in this order:

| Column | Contents | Values |
|---|---|---|
| 1 | Team | team name |
| 2 | Country | `C` (Canada) or `U` (United States) |
| 3 | Player | player name |
| 4 | Position | `F`, `C`, `D` or `G` (`C` is recoded to `F`) |
| 5 | Pre-tax salary | annual salary in dollars |
| 6 | After-tax salary | annual salary after tax, in dollars |

Rows with a missing value in any of these columns are dropped, which leaves the
787 players treated as the population in the report.

Sources are listed in the references of the report.
