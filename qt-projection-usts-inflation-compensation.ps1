
# $result_as_of_dates = Invoke-RestMethod https://markets.newyorkfed.org/api/soma/asofdates/list.json 
# 
# $result_as_of_dates.soma.asOfDates | Sort-Object | Select-Object -Last 20

# $dates = @(
#     '2022-11-02'
#     '2022-11-09'
#     '2022-11-16'
#     '2022-11-23'
#     '2022-11-30'
# )

# $dates = @(
#     '2022-11-30'
#     '2022-12-07'
#     '2022-12-14'
#     '2022-12-21'
#     '2022-12-28'
#     '2023-01-04'
# )

# $dates = @(
#     '2023-01-04'
#     '2023-01-11'
#     '2023-01-18'
#     '2023-01-25'
#     '2023-02-01'
# )

# $dates = @(
#     '2023-02-01'
#     '2023-02-08'
#     '2023-02-15'
#     '2023-02-22'
#     '2023-03-01'
# )

# $dates = @(
#     '2023-03-01'
#     '2023-03-08'
#     '2023-03-15'
#     '2023-03-22'
#     '2023-03-29'
#     '2023-04-05'
# )

# $dates = @(
#     '2023-04-05'
#     '2023-04-12'
#     '2023-04-19'
#     '2023-04-26'
#     '2023-05-03'
# )

$dates = @(
    '2023-05-03'
    '2023-05-10'
    '2023-05-17'
    '2023-05-24'
    '2023-05-31'
    '2023-06-07'
)


$result = Invoke-RestMethod ('https://markets.newyorkfed.org/api/soma/tsy/get/all/asof/{0}.json' -f $dates[0])

$maturing = $result.soma.holdings | Sort-Object maturityDate | Where-Object maturityDate -LE $dates[-1]

$notes_bonds_sum = ($maturing | Where-Object securityType -EQ 'NotesBonds' | Measure-Object -Property parValue -Sum).Sum
$bills_sum       = ($maturing | Where-Object securityType -EQ 'Bills'      | Measure-Object -Property parValue -Sum).Sum
$frns_sum        = ($maturing | Where-Object securityType -EQ 'FRNs'       | Measure-Object -Property parValue -Sum).Sum
$tips_sum        = ($maturing | Where-Object securityType -EQ 'TIPS'       | Measure-Object -Property parValue -Sum).Sum

$tips_inflation_compensation = ($maturing | Where-Object securityType -EQ 'TIPS'       | Measure-Object -Property inflationCompensation -Sum).Sum


# $notes_bonds_frns_tips_sum = $notes_bonds_sum + $frns_sum + $tips_sum
$notes_bonds_frns_tips_sum = $notes_bonds_sum + $frns_sum + $tips_sum + $tips_inflation_compensation

$notes_bonds_frns_tips_to_rolloff = [math]::Min($notes_bonds_frns_tips_sum, 60000000000)
# $notes_bonds_frns_tips_to_rolloff = [math]::Min($notes_bonds_frns_tips_sum + $tips_inflation_compensation, 60000000000)

$bills_to_rolloff = [math]::Max(60000000000 - $notes_bonds_frns_tips_sum, 0)

$notes_bonds_frns_tips_rolloff_percentage = $notes_bonds_frns_tips_to_rolloff / $notes_bonds_frns_tips_sum
# $notes_bonds_frns_tips_rolloff_percentage = ($notes_bonds_frns_tips_to_rolloff + $tips_inflation_compensation) / $notes_bonds_frns_tips_sum
$bills_rolloff_percentage                 = $bills_to_rolloff                 / $bills_sum

# foreach ($row in $maturing)
# {
#     if     ($row.securityType -eq 'Bills')      { $row | Add-Member -MemberType NoteProperty -Name rolloff -Value ([math]::Round(([decimal] $row.parValue * $bills_rolloff_percentage), 0)) }
#     elseif ($row.securityType -eq 'FRNs')       { $row | Add-Member -MemberType NoteProperty -Name rolloff -Value ([math]::Round(([decimal] $row.parValue * $notes_bonds_frns_tips_rolloff_percentage), 0)) }
#     elseif ($row.securityType -eq 'TIPS')       { $row | Add-Member -MemberType NoteProperty -Name rolloff -Value ([math]::Round(([decimal] $row.parValue * $notes_bonds_frns_tips_rolloff_percentage), 0)) }
#     elseif ($row.securityType -eq 'NotesBonds') { $row | Add-Member -MemberType NoteProperty -Name rolloff -Value ([math]::Round(([decimal] $row.parValue * $notes_bonds_frns_tips_rolloff_percentage), 0)) }
# }


foreach ($row in $maturing)
{
    if     ($row.securityType -eq 'Bills')      { $row | Add-Member -MemberType NoteProperty -Name rolloff -Value ([math]::Round( [decimal] $row.parValue                                         * $bills_rolloff_percentage,                 0)) }
    elseif ($row.securityType -eq 'FRNs')       { $row | Add-Member -MemberType NoteProperty -Name rolloff -Value ([math]::Round( [decimal] $row.parValue                                         * $notes_bonds_frns_tips_rolloff_percentage, 0)) }
    elseif ($row.securityType -eq 'NotesBonds') { $row | Add-Member -MemberType NoteProperty -Name rolloff -Value ([math]::Round( [decimal] $row.parValue                                         * $notes_bonds_frns_tips_rolloff_percentage, 0)) }
    elseif ($row.securityType -eq 'TIPS')       { $row | Add-Member -MemberType NoteProperty -Name rolloff -Value ([math]::Round(([decimal] $row.parValue + [decimal] $row.inflationCompensation) * $notes_bonds_frns_tips_rolloff_percentage, 0)) }
}

# foreach ($row in $maturing)
# {
#     $row.PSObject.Properties.Remove('rolloff')
# }

foreach ($row in $result.soma.holdings)
{
        $row | Add-Member -MemberType NoteProperty -Name rolloff_week_total -Value ''
        $row | Add-Member -MemberType NoteProperty -Name report_date        -Value ''
}

# foreach ($row in $result.soma.holdings)
# {
#     $row.PSObject.Properties.Remove('rolloff_week_total')
#     $row.PSObject.Properties.Remove('report_date')
# }

function loop ($dates)
{
    if ($dates.Count -ge 2)
    {
        $a = $dates[0]
        $b = $dates[1]
                
        # $items = $maturing | Where-Object maturityDate -GE $a | Where-Object maturityDate -LE $b

        $items = $maturing | Where-Object maturityDate -GT $a | Where-Object maturityDate -LE $b
                
        $items[-1].rolloff_week_total = ('{0,20}' -f ($items | Measure-Object -Property rolloff -Sum).Sum.ToString('C0'))

        $items[-1].report_date = $b

        loop ($dates | Select-Object -Skip 1)
    }
}

loop $dates 

$fields = @(
    'asOfDate'
    'cusip'
    'maturityDate'
    'issuer'
    'spread'
    'coupon'
    @{ Label = 'parValue';              Expression = { ([decimal]$_.parValue).ToString('N0') };              Align = 'right' }
    @{ Label = 'inflationCompensation'; Expression = { ([decimal]$_.inflationCompensation).ToString('N0') }; Align = 'right' }
    @{ Label = 'percentOutstanding';    Expression = { ([decimal]$_.percentOutstanding).ToString('N3') };    Align = 'right' }
    @{ Label = 'changeFromPriorWeek';   Expression = { ([decimal]$_.changeFromPriorWeek).ToString('N0') };   Align = 'right' }
    @{ Label = 'changeFromPriorYear';   Expression = { ([decimal]$_.changeFromPriorYear).ToString('N0') };   Align = 'right' }
    'securityType'
    @{ Label = 'rolloff'; Expression = { ([decimal]$_.rolloff).ToString('N0') }; Align = 'right' }
    'rolloff_week_total'
    'report_date'        
)

$maturing | Format-Table $fields

exit

# ----------------------------------------------------------------------

$result = Invoke-RestMethod ('https://markets.newyorkfed.org/api/soma/tsy/get/all/asof/{0}.json' -f $dates[0])

$result.soma.holdings | Sort-Object maturityDate | Where-Object inflationCompensation -NE '' | ft *


$tips_sum        = 

$maturing | ft *

($maturing | Where-Object securityType -EQ 'TIPS'       | Measure-Object -Property inflationCompensation -Sum).Sum