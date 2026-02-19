@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @()
    IncludeRules = @(
        'PSAvoidUsingCmdletAliases',
        'PSAvoidUsingWriteHost',
        'PSUseApprovedVerbs'
    )
}
