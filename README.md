# NHL Player Salaries: A Finite Population Sampling Study

Course project for MATH 3430 (Sample Survey Design), York University, Winter 2026.

**Author:** Neill Botushanski. This was a group project, completed with two teammates.

The full write-up is in [`report/NHL_Salary_Report.pdf`](report/NHL_Salary_Report.pdf).

## 1. Question

Two questions are studied on a population of 787 NHL players:

1. How precisely can the mean and total salary be estimated from a sample of 120 players, and how much does stratifying by playing position improve on simple random sampling?
2. Does the comparison between Canadian and U.S. teams change once salaries are adjusted for tax?

The 787 players are treated as a fully known finite population. The true population means are therefore available as a benchmark, and the only randomness is the sampling mechanism.

## 2. Design

| Item | Choice |
|---|---|
| Population | N = 787 players: 269 defensemen (D), 448 forwards (F), 70 goaltenders (G) |
| Variables | Pre-tax salary and after-tax salary |
| Sample size | n = 120 in every design (sampling fraction 15.2%) |
| Design 1 | Simple random sampling without replacement (SRSWOR) |
| Design 2 | Stratified by position, proportional allocation: 41 D, 68 F, 11 G |
| Design 3 | Stratified by position, Neyman allocation: 42 D, 68 F, 10 G for pre-tax salary; 42 D, 67 F, 11 G for after-tax salary |
| Estimators | Mean and total with the finite population correction, 95% confidence intervals |
| Comparison | Relative efficiency, the ratio of estimated variances |
| Seed | `set.seed(123)` |

Fractional allocations are rounded with the largest-remainder method. The Neyman allocation uses the population standard deviations of each stratum, which is possible here only because the whole population is known.

## 3. Results

**Pre-tax salary** (true population mean: $3,650,480)

| Design | Estimated mean | Standard error | 95% confidence interval |
|---|---:|---:|---:|
| SRSWOR | $4,170,330 | $251,076 | $3,678,222 to $4,662,439 |
| Stratified, proportional | $3,362,231 | $233,777 | $2,904,028 to $3,820,434 |
| Stratified, Neyman | $3,349,263 | $231,276 | $2,895,962 to $3,802,563 |

**After-tax salary** (true population mean: $1,634,604)

| Design | Estimated mean | Standard error | 95% confidence interval |
|---|---:|---:|---:|
| SRSWOR | $1,899,015 | $118,662 | $1,666,438 to $2,131,592 |
| Stratified, proportional | $1,540,873 | $111,886 | $1,321,575 to $1,760,170 |
| Stratified, Neyman | $1,535,275 | $110,892 | $1,317,927 to $1,752,623 |

**Relative efficiency** (a value above 1 means the first design has the smaller variance)

| Comparison | Pre-tax | After-tax |
|---|---:|---:|
| Proportional vs. SRSWOR | 1.1535 | 1.1248 |
| Neyman vs. SRSWOR | 1.1786 | 1.1450 |
| Neyman vs. proportional | 1.0217 | 1.0180 |

What the numbers show:

- **Stratifying by position helps, modestly.** Proportional allocation lowers the variance of the estimated mean by 13.3% for pre-tax salary and 11.1% for after-tax salary. Neyman allocation lowers it by 15.2% and 12.7%.
- **Neyman adds little over proportional.** The gain is about 2%, because the three positions have almost the same salary spread (a standard deviation near $2.8 million pre-tax in each). When the stratum standard deviations are equal, the two allocations coincide.
- **Position is a weak predictor of salary.** Mean pre-tax salaries are $3.67 million (D), $3.63 million (F) and $3.69 million (G).
- **The regional ranking changes after tax.** Before tax, U.S. teams pay more on average for defensemen and goaltenders. After tax, Canadian defensemen and forwards keep more, and the gap for goaltenders nearly disappears.

## 4. Structure

```text
README.md                       this file
R/nhl_salary_sampling.R         data cleaning, the three sampling designs, estimators, figures
report/NHL_Salary_Report.pdf    the report
report/NHL_Salary_Report.tex    LaTeX source of the report
data/README.md                  layout of the input workbook (the data are not included)
```

## 5. Reproduction

The analysis is written in R and needs the packages `readxl`, `dplyr`, `ggplot2`, `scales` and `tidyr`:

```r
install.packages(c("readxl", "dplyr", "ggplot2", "scales", "tidyr"))
```

Save the workbook as `data/nhl_salaries.xlsx` (layout in [`data/README.md`](data/README.md)), set the working directory to the repository root, and run:

```r
source("R/nhl_salary_sampling.R", echo = TRUE)
```

The script leaves its results in these objects:

| Object | Contents |
|---|---|
| `srs_sample`, `prop_sample` | the SRSWOR and proportional samples |
| `prop_pre`, `prop_after` | proportional estimates for pre-tax and after-tax salary |
| `neyman_pre`, `neyman_after` | Neyman estimates for pre-tax and after-tax salary |
| `RE_prop_pre`, `RE_neyman_pre`, `RE_prop_after`, `RE_neyman_after` | relative efficiencies against SRSWOR |
| `comparison_by_position_region` | population means by position and region |

To rebuild the PDF (the appendix reads the script from `R/`, so compile inside `report/`):

```bash
cd report
latexmk -pdf NHL_Salary_Report.tex
```

## 6. Limitations

- Salaries are strongly right-skewed, so a few very large contracts drive the within-stratum variance and limit what stratifying by position can gain.
- The data cover a single season.
- The after-tax salary rests on a simplified tax calculation.
- The Neyman allocation uses population standard deviations, which a real survey would have to estimate.
- Each design is evaluated on one sample draw; a simulation over many draws would confirm the efficiency figures.

## References

Cochran, W. G. (1977). *Sampling techniques* (3rd ed.). Wiley.

Thompson, S. K. (2012). *Sampling* (3rd ed.). Wiley.

Spotrac. NHL contract average rankings. https://www.spotrac.com/nhl/rankings/player/_/year/2025/sort/contract_average

The Commute Sports (2019). NHL salary analysis. https://thecommutesports.com/2019/09/07/nhl-salary-analysis/
