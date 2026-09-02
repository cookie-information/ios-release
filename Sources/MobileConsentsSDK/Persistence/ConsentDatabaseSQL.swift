import Foundation

enum ConsentDatabaseSQL: CaseIterable {
    case journalMode
    case userVersion
    case foreignKeys
    case beginImmediate
    case begin
    case commit
    case rollback

    case insertProfile
    case deleteProfile
    case selectAnonymousUserID
    case selectLegacyResolution
    case insertLegacyResolution
    case selectEmptyDatabase
    case selectSchemaDefinitions
    case selectUserTableNames
    case insertLatestSolution
    case selectLatestSolution
    case selectLatestDecision
    case selectDecisionForInsert
    case deleteDecision
    case insertDecision
    case insertDecisionChoice
    case claimPendingSynchronization
    case hasPendingSynchronization
    case isSynchronizationClaimCurrent
    case transitionSynchronizationClaim
    case insertConfiguration
    case selectConfigurationID
    case insertSolutionVersion
    case selectSolutionVersionID
    case insertSolutionItem
    case insertSolutionItemTranslation
    case selectSolutionItems
    case selectSolutionItemTranslations

    var sql: String {
        switch self {
        case .journalMode: "PRAGMA journal_mode;"
        case .userVersion: "PRAGMA user_version;"
        case .foreignKeys: "PRAGMA foreign_keys = ON;"
        case .beginImmediate: "BEGIN IMMEDIATE;"
        case .begin: "BEGIN;"
        case .commit: "COMMIT;"
        case .rollback: "ROLLBACK;"
        case .insertProfile: "INSERT INTO consent_profile (id, external_user_id) VALUES (:id, NULL);"
        case .deleteProfile: "DELETE FROM consent_profile;"
        case .selectAnonymousUserID: "SELECT id FROM consent_profile WHERE external_user_id IS NULL;"
        case .selectLegacyResolution: "SELECT 1 FROM consent_legacy_resolution WHERE id = 1;"
        case .insertLegacyResolution:
            """
    INSERT INTO consent_legacy_resolution (id, kind, configuration_id)
    VALUES (1, :kind, :configurationID)
    ON CONFLICT (id) DO UPDATE SET
        kind = excluded.kind,
        configuration_id = excluded.configuration_id;
    """
        case .selectEmptyDatabase:
            """
    SELECT 1
    FROM sqlite_master
    WHERE name NOT LIKE 'sqlite_%'
    LIMIT 1;
    """
        case .selectSchemaDefinitions:
            """
    SELECT type, name, sql
    FROM sqlite_master
    WHERE type IN ('table', 'index')
        AND name NOT LIKE 'sqlite_%'
        AND sql IS NOT NULL
    ORDER BY type, name;
    """
        case .selectUserTableNames: "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%';"
        case .insertLatestSolution:
            """
    INSERT INTO consent_latest_solution (
        configuration_id, solution_version_row_id
    ) VALUES (:configurationID, :solutionVersionRowID)
    ON CONFLICT (configuration_id) DO UPDATE SET
        solution_version_row_id = excluded.solution_version_row_id;
    """
        case .selectLatestSolution:
            """
    SELECT version.id, version.solution_id, version.version_id, version.template_texts
    FROM consent_latest_solution AS latest
    JOIN consent_configuration AS configuration
        ON configuration.id = latest.configuration_id
    JOIN consent_solution_version AS version
        ON version.id = latest.solution_version_row_id
    WHERE configuration.solution_id = :solutionID
        AND configuration.client_id = :clientID
        AND configuration.configuration_digest = :configurationDigest;
    """
        case .selectLatestDecision:
            """
    SELECT decision.solution_version_id, decision.submission
    FROM consent_decision AS decision
    JOIN consent_configuration AS configuration
        ON configuration.id = decision.configuration_id
    WHERE decision.profile_id = :profileID
        AND configuration.solution_id = :solutionID
        AND configuration.client_id = :clientID
        AND configuration.configuration_digest = :configurationDigest
    ORDER BY decision.id DESC
    LIMIT 1;
    """
        case .selectDecisionForInsert:
            """
    SELECT synchronization_state, claimed_at
    FROM consent_decision
    WHERE profile_id = :profileID AND configuration_id = :configurationID AND solution_version_id = :solutionVersionID;
    """
        case .deleteDecision:
            """
    DELETE FROM consent_decision
    WHERE profile_id = :profileID AND configuration_id = :configurationID AND solution_version_id = :solutionVersionID;
    """
        case .insertDecision:
            """
    INSERT INTO consent_decision (
        profile_id, configuration_id, solution_version_id, revision_id,
        submission, synchronization_state, claimed_at
        ) VALUES (:profileID, :configurationID, :solutionVersionID, :revisionID, :submission, :synchronizationState, :claimedAt)
    RETURNING id;
    """
        case .insertDecisionChoice:
            """
    INSERT INTO consent_decision_choice (
        decision_id, position, universal_id, accepted
    ) VALUES (:decisionID, :position, :universalID, :accepted);
    """
        case .claimPendingSynchronization:
            """
    WITH candidate AS (
        SELECT decision.id
        FROM consent_decision AS decision
        JOIN consent_configuration AS configuration
            ON configuration.id = decision.configuration_id
        WHERE configuration.solution_id = :solutionID
            AND configuration.client_id = :clientID
            AND configuration.configuration_digest = :configurationDigest
            AND NOT EXISTS (
                SELECT 1
                FROM consent_decision AS active
                WHERE active.configuration_id = decision.configuration_id
                    AND active.synchronization_state = 'in_progress'
                    AND active.claimed_at >= :abandonedBefore
            )
            AND (
                decision.synchronization_state = 'pending'
                OR (
                    decision.synchronization_state = 'in_progress'
                    AND decision.claimed_at < :abandonedBefore
                )
            )
        ORDER BY decision.id
        LIMIT 1
    )
    UPDATE consent_decision
    SET synchronization_state = 'in_progress', claimed_at = :claimedAt
    WHERE id = (SELECT id FROM candidate)
    RETURNING profile_id, revision_id, solution_version_id, submission, claimed_at;
    """
        case .hasPendingSynchronization:
            """
    SELECT 1
    FROM consent_decision AS decision
    JOIN consent_configuration AS configuration
        ON configuration.id = decision.configuration_id
    WHERE configuration.solution_id = :solutionID
        AND configuration.client_id = :clientID
        AND configuration.configuration_digest = :configurationDigest
        AND decision.synchronization_state IN ('pending', 'in_progress')
    LIMIT 1;
    """
        case .isSynchronizationClaimCurrent:
            """
    SELECT 1 FROM consent_decision
    WHERE profile_id = :profileID
        AND configuration_id = (
            SELECT id FROM consent_configuration
            WHERE solution_id = :solutionID AND client_id = :clientID AND configuration_digest = :configurationDigest
        )
        AND solution_version_id = :solutionVersionID
        AND revision_id = :revisionID
        AND synchronization_state = 'in_progress'
        AND claimed_at = :claimedAt;
    """
        case .transitionSynchronizationClaim:
            """
    UPDATE consent_decision
    SET synchronization_state = CASE
            WHEN revision_id = :revisionID THEN :state
            ELSE 'pending'
        END,
        claimed_at = NULL
    WHERE profile_id = :profileID
        AND configuration_id = (
            SELECT id FROM consent_configuration
            WHERE solution_id = :solutionID AND client_id = :clientID AND configuration_digest = :configurationDigest
        )
        AND solution_version_id = :solutionVersionID
        AND synchronization_state = 'in_progress'
        AND claimed_at = :claimedAt
    RETURNING 1;
    """
        case .insertConfiguration:
            """
    INSERT INTO consent_configuration (solution_id, client_id, configuration_digest)
    VALUES (:solutionID, :clientID, :configurationDigest)
    ON CONFLICT (solution_id, client_id, configuration_digest) DO NOTHING;
    """
        case .selectConfigurationID:
            """
    SELECT id FROM consent_configuration
    WHERE solution_id = :solutionID AND client_id = :clientID AND configuration_digest = :configurationDigest;
    """
        case .insertSolutionVersion:
            """
    INSERT INTO consent_solution_version (
        configuration_id, solution_id, version_id, template_texts
    ) VALUES (:configurationID, :solutionID, :versionID, :templateTexts)
    ON CONFLICT (configuration_id, version_id) DO NOTHING;
    """
        case .selectSolutionVersionID:
            """
    SELECT id FROM consent_solution_version
    WHERE configuration_id = :configurationID AND version_id = :versionID;
    """
        case .insertSolutionItem:
            """
    INSERT INTO consent_solution_item (
        solution_version_row_id, universal_id, position, required, type
    ) VALUES (:solutionVersionRowID, :universalID, :position, :required, :type);
    """
        case .insertSolutionItemTranslation:
            """
    INSERT INTO consent_solution_item_translation (
        consent_item_row_id, language, position, short_text, long_text
    ) VALUES (:consentItemRowID, :language, :position, :shortText, :longText);
    """
        case .selectSolutionItems:
            """
    SELECT id, universal_id, required, type
    FROM consent_solution_item
    WHERE solution_version_row_id = :solutionVersionRowID
    ORDER BY position;
    """
        case .selectSolutionItemTranslations:
            """
    SELECT language, short_text, long_text
    FROM consent_solution_item_translation
    WHERE consent_item_row_id = :consentItemRowID
    ORDER BY position;
    """
        }
    }

}