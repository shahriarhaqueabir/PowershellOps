@{
    # Curated ruleset for the PowershellOps installer + modules.
    # Gate: Error-severity findings fail the build; Warnings are reported.
    Severity     = @('Error', 'Warning')
    IncludeRules = @('*')
    ExcludeRules = @(
        # Deliberate UI output throughout installer/profile code.
        'PSAvoidUsingWriteHost',
        # Installer step scripts are state-changing by design and never exported.
        'PSUseShouldProcessForStateChangingFunctions',
        # No credential parameters exist in this codebase.
        'PSAvoidUsingPlainTextForPassword',
        'PSAvoidUsingUsernameAndPasswordParams',
        # Files intentionally carry emoji/Nerd Font glyphs; BOM policy is manual.
        'PSUseBOMForUnicodeEncodedFile',
        # Alias usage is intentional in profile/dashboard ergonomics.
        'PSAvoidUsingCmdletAliases',
        # Diagnostic getters intentionally return collections (Get-HawkApps, ...).
        'PSUseSingularNouns',
        # Empty catch blocks here are deliberate best-effort guards around
        # UI/dashboard probes where failure must never break rendering.
        'PSAvoidUsingEmptyCatchBlock',
        # Prompt/dashboard state is shared across profile scope by design.
        'PSAvoidGlobalVars',
        # Step/module param blocks accept config keys even when a given
        # entry point doesn't consume them (stable CLI surface).
        'PSReviewUnusedParameter'
    )
}
