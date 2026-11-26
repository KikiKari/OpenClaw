<?php
// abstraction-provenance: {"artifact_sha256": "daf1f538cfddf514be9b091ca276a77196f2a101b593480bbcb6461f641e10af", "source_sha256": "a34985d25128cedfc16fb8a861471a22db49d62133276bbab6c7492eee461c4d", "target_language": "php"}
// npm-publish-plan.mjs — portiert nach php
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/npm-publish-plan.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
const STABLE_VERSION_REGEX = '/^(?<year>\d{4})\.(?<month>[1-9]\d?)\.(?<day>[1-9]\d?)$/';
const BETA_VERSION_REGEX =
  '/^(?<year>\d{4})\.(?<month>[1-9]\d?)\.(?<day>[1-9]\d?)-beta\.(?<beta>[1-9]\d*)$/';
const CORRECTION_VERSION_REGEX =
  '/^(?<year>\d{4})\.(?<month>[1-9]\d?)\.(?<day>[1-9]\d?)-(?<correction>[1-9]\d*)$/';

/**
 * @param string $version
 * @param array<string, string|null> $groups
 * @param string $channel
 * @return array<string,mixed>|null
 */
function parseDateParts($version, $groups, $channel) {
    $year = intval($groups['year'] ?? "");
    $month = intval($groups['month'] ?? "");
    $day = intval($groups['day'] ?? "");
    $betaNumber = $channel === "beta" ? intval($groups['beta'] ?? "") : null;

    if (
        !is_int($year) ||
        !is_int($month) ||
        !is_int($day) ||
        $month < 1 ||
        $month > 12 ||
        $day < 1 ||
        $day > 31
    ) {
        return null;
    }
    if ($channel === "beta" && (!is_int($betaNumber) || ($betaNumber ?? 0) < 1)) {
        return null;
    }

    $date = new DateTime("{$year}-{$month}-{$day}", new DateTimeZone('UTC'));
    if (
        intval($date->format('Y')) !== $year ||
        intval($date->format('n')) !== $month ||
        intval($date->format('j')) !== $day
    ) {
        return null;
    }

    return [
        'version' => $version,
        'baseVersion' => "{$year}.{$month}.{$day}",
        'channel' => $channel,
        'year' => $year,
        'month' => $month,
        'day' => $day,
        'betaNumber' => $betaNumber,
        'date' => $date,
    ];
}

/**
 * @param string $version
 * @return array<string,mixed>|null
 */
function parseReleaseVersion($version) {
    $trimmed = trim($version);
    if (!$trimmed) {
        return null;
    }

    if (preg_match(STABLE_VERSION_REGEX, $trimmed, $stableMatch)) {
        return parseDateParts($trimmed, $stableMatch, "stable");
    }

    if (preg_match(BETA_VERSION_REGEX, $trimmed, $betaMatch)) {
        return parseDateParts($trimmed, $betaMatch, "beta");
    }

    if (preg_match(CORRECTION_VERSION_REGEX, $trimmed, $correctionMatch)) {
        $parsedCorrection = parseDateParts($trimmed, $correctionMatch, "stable");
        $correctionNumber = intval($correctionMatch['correction'] ?? "");
        if ($parsedCorrection === null || !is_int($correctionNumber) || $correctionNumber < 1) {
            return null;
        }

        $parsedCorrection['correctionNumber'] = $correctionNumber;
        return $parsedCorrection;
    }

    return null;
}

/**
 * @param string $left
 * @param string $right
 * @return int|null
 */
function compareReleaseVersions($left, $right) {
    $parsedLeft = parseReleaseVersion($left);
    $parsedRight = parseReleaseVersion($right);
    if ($parsedLeft === null || $parsedRight === null) {
        return null;
    }

    $dateDelta = $parsedLeft['date']->getTimestamp() - $parsedRight['date']->getTimestamp();
    if ($dateDelta !== 0) {
        return $dateDelta <=> 0;
    }

    if ($parsedLeft['channel'] !== $parsedRight['channel']) {
        return $parsedLeft['channel'] === "stable" ? 1 : -1;
    }

    if ($parsedLeft['channel'] === "beta" && $parsedRight['channel'] === "beta") {
        return ($parsedLeft['betaNumber'] ?? 0) <=> ($parsedRight['betaNumber'] ?? 0);
    }

    return ($parsedLeft['correctionNumber'] ?? 0) <=> ($parsedRight['correctionNumber'] ?? 0);
}

/**
 * @param string $version
 * @param string|null $currentBetaVersion
 * @return array<string,mixed>
 */
function resolveNpmPublishPlan($version, $currentBetaVersion = null) {
    $parsedVersion = parseReleaseVersion($version);
    if ($parsedVersion === null) {
        throw new Exception("Unsupported release version \"{$version}\".");
    }

    if ($parsedVersion['channel'] === "beta") {
        return [
            'channel' => "beta",
            'publishTag' => "beta",
            'mirrorDistTags' => [],
        ];
    }

    $normalizedCurrentBeta = $currentBetaVersion ? trim($currentBetaVersion) : null;
    if ($normalizedCurrentBeta) {
        $betaVsStable = compareReleaseVersions($normalizedCurrentBeta, $version);
        if ($betaVsStable !== null && $betaVsStable > 0) {
            return [
                'channel' => "stable",
                'publishTag' => "latest",
                'mirrorDistTags' => [],
            ];
        }
    }

    return [
        'channel' => "stable",
        'publishTag' => "latest",
        'mirrorDistTags' => ["beta"],
    ];
}

/**
 * @param array<string,mixed>|null $params
 * @return array<string,mixed>
 */
function resolveNpmDistTagMirrorAuth($params = null) {
    if ($params === null) {
        $params = [];
    }
    
    $nodeAuthToken = isset($params['nodeAuthToken']) ? trim($params['nodeAuthToken']) : '';
    if ($nodeAuthToken) {
        return ['hasAuth' => true, 'source' => "node-auth-token"];
    }

    $npmToken = isset($params['npmToken']) ? trim($params['npmToken']) : '';
    if ($npmToken) {
        return ['hasAuth' => true, 'source' => "npm-token"];
    }

    return ['hasAuth' => false, 'source' => "none"];
}

/**
 * @param array<string,mixed> $params
 * @return bool
 */
function shouldRequireNpmDistTagMirrorAuth($params) {
    return (
        $params['mode'] === "--publish" &&
        count(array_filter($params['mirrorDistTags'], function($distTag) {
            return strlen(trim($distTag)) > 0;
        })) > 0 &&
        !$params['hasAuth']
    );
}
