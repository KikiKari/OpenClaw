// abstraction-provenance: {"artifact_sha256": "c73a31e23cd21927519d1d46b0b6ec7a55ffd1763a54432018a2d686e1b4f1a2", "source_sha256": "a34985d25128cedfc16fb8a861471a22db49d62133276bbab6c7492eee461c4d", "target_language": "java"}
// npm-publish-plan.mjs — portiert nach java
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/npm-publish-plan.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.function.Function;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

public class NpmPublishPlan {

    private static final Pattern STABLE_VERSION_REGEX = Pattern.compile(
            "^(?<year>\\d{4})\\.(?<month>[1-9]\\d?)\\.(?<day>[1-9]\\d?)$"
    );
    private static final Pattern BETA_VERSION_REGEX = Pattern.compile(
            "^(?<year>\\d{4})\\.(?<month>[1-9]\\d?)\\.(?<day>[1-9]\\d?)-beta\\.(?<beta>[1-9]\\d*)$"
    );
    private static final Pattern CORRECTION_VERSION_REGEX = Pattern.compile(
            "^(?<year>\\d{4})\\.(?<month>[1-9]\\d?)\\.(?<day>[1-9]\\d?)-(?<correction>[1-9]\\d*)$"
    );

    public enum Channel {
        STABLE("stable"),
        BETA("beta");

        private final String value;

        Channel(String value) {
            this.value = value;
        }

        public String getValue() {
            return value;
        }
    }

    public enum PublishTag {
        LATEST("latest"),
        BETA("beta");

        private final String value;

        PublishTag(String value) {
            this.value = value;
        }

        public String getValue() {
            return value;
        }
    }

    public enum AuthSource {
        NODE_AUTH_TOKEN("node-auth-token"),
        NPM_TOKEN("npm-token"),
        NONE("none");

        private final String value;

        AuthSource(String value) {
            this.value = value;
        }

        public String getValue() {
            return value;
        }
    }

    public enum NpmPublishMode {
        DRY_RUN("--dry-run"),
        PUBLISH("--publish");

        private final String value;

        NpmPublishMode(String value) {
            this.value = value;
        }

        public String getValue() {
            return value;
        }
    }

    public static class ParsedReleaseVersion {
        private final String version;
        private final String baseVersion;
        private final Channel channel;
        private final int year;
        private final int month;
        private final int day;
        private final Integer betaNumber;
        private final Integer correctionNumber;
        private final LocalDate date;

        public ParsedReleaseVersion(String version, String baseVersion, Channel channel, int year, int month, int day, Integer betaNumber, Integer correctionNumber, LocalDate date) {
            this.version = version;
            this.baseVersion = baseVersion;
            this.channel = channel;
            this.year = year;
            this.month = month;
            this.day = day;
            this.betaNumber = betaNumber;
            this.correctionNumber = correctionNumber;
            this.date = date;
        }

        public String getVersion() {
            return version;
        }

        public String getBaseVersion() {
            return baseVersion;
        }

        public Channel getChannel() {
            return channel;
        }

        public int getYear() {
            return year;
        }

        public int getMonth() {
            return month;
        }

        public int getDay() {
            return day;
        }

        public Integer getBetaNumber() {
            return betaNumber;
        }

        public Integer getCorrectionNumber() {
            return correctionNumber;
        }

        public LocalDate getDate() {
            return date;
        }

        @Override
        public boolean equals(Object o) {
            if (this == o) return true;
            if (o == null || getClass() != o.getClass()) return false;
            ParsedReleaseVersion that = (ParsedReleaseVersion) o;
            return year == that.year && month == that.month && day == that.day && Objects.equals(version, that.version) && Objects.equals(baseVersion, that.baseVersion) && channel == that.channel && Objects.equals(betaNumber, that.betaNumber) && Objects.equals(correctionNumber, that.correctionNumber) && Objects.equals(date, that.date);
        }

        @Override
        public int hashCode() {
            return Objects.hash(version, baseVersion, channel, year, month, day, betaNumber, correctionNumber, date);
        }
    }

    public static class NpmPublishPlanResult {
        private final Channel channel;
        private final PublishTag publishTag;
        private final List<PublishTag> mirrorDistTags;

        public NpmPublishPlanResult(Channel channel, PublishTag publishTag, List<PublishTag> mirrorDistTags) {
            this.channel = channel;
            this.publishTag = publishTag;
            this.mirrorDistTags = Collections.unmodifiableList(mirrorDistTags);
        }

        public Channel getChannel() {
            return channel;
        }

        public PublishTag getPublishTag() {
            return publishTag;
        }

        public List<PublishTag> getMirrorDistTags() {
            return mirrorDistTags;
        }

        @Override
        public boolean equals(Object o) {
            if (this == o) return true;
            if (o == null || getClass() != o.getClass()) return false;
            NpmPublishPlanResult that = (NpmPublishPlanResult) o;
            return channel == that.channel && publishTag == that.publishTag && Objects.equals(mirrorDistTags, that.mirrorDistTags);
        }

        @Override
        public int hashCode() {
            return Objects.hash(channel, publishTag, mirrorDistTags);
        }
    }

    public static class NpmDistTagMirrorAuth {
        private final boolean hasAuth;
        private final AuthSource source;

        public NpmDistTagMirrorAuth(boolean hasAuth, AuthSource source) {
            this.hasAuth = hasAuth;
            this.source = source;
        }

        public boolean isHasAuth() {
            return hasAuth;
        }

        public AuthSource getSource() {
            return source;
        }

        @Override
        public boolean equals(Object o) {
            if (this == o) return true;
            if (o == null || getClass() != o.getClass()) return false;
            NpmDistTagMirrorAuth that = (NpmDistTagMirrorAuth) o;
            return hasAuth == that.hasAuth && source == that.source;
        }

        @Override
        public int hashCode() {
            return Objects.hash(hasAuth, source);
        }
    }

    /**
     * Parses date parts from regex groups and validates them.
     *
     * @param version The version string being parsed
     * @param groups  The named groups from the regex match
     * @param channel The release channel (stable or beta)
     * @return A ParsedReleaseVersion object or null if invalid
     */
    private static ParsedReleaseVersion parseDateParts(String version, Map<String, String> groups, Channel channel) {
        try {
            int year = Integer.parseInt(groups.getOrDefault("year", ""));
            int month = Integer.parseInt(groups.getOrDefault("month", ""));
            int day = Integer.parseInt(groups.getOrDefault("day", ""));
            Integer betaNumber = channel == Channel.BETA ? Integer.parseInt(groups.getOrDefault("beta", "")) : null;

            if (month < 1 || month > 12 || day < 1 || day > 31) {
                return null;
            }

            if (channel == Channel.BETA && (betaNumber == null || betaNumber < 1)) {
                return null;
            }

            LocalDate date = LocalDate.of(year, month, day);
            if (date.getYear() != year || date.getMonthValue() != month || date.getDayOfMonth() != day) {
                return null;
            }

            String baseVersion = String.format("%d.%d.%d", year, month, day);

            return new ParsedReleaseVersion(version, baseVersion, channel, year, month, day, betaNumber, null, date);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    /**
     * Parses a release version string into its components.
     *
     * @param version The version string to parse
     * @return A ParsedReleaseVersion object or null if invalid
     */
    public static ParsedReleaseVersion parseReleaseVersion(String version) {
        String trimmed = version.trim();
        if (trimmed.isEmpty()) {
            return null;
        }

        Matcher stableMatcher = STABLE_VERSION_REGEX.matcher(trimmed);
        if (stableMatcher.matches()) {
            return parseDateParts(trimmed, getNamedGroups(stableMatcher), Channel.STABLE);
        }

        Matcher betaMatcher = BETA_VERSION_REGEX.matcher(trimmed);
        if (betaMatcher.matches()) {
            return parseDateParts(trimmed, getNamedGroups(betaMatcher), Channel.BETA);
        }

        Matcher correctionMatcher = CORRECTION_VERSION_REGEX.matcher(trimmed);
        if (correctionMatcher.matches()) {
            Map<String, String> groups = getNamedGroups(correctionMatcher);
            ParsedReleaseVersion parsedCorrection = parseDateParts(trimmed, groups, Channel.STABLE);
            try {
                Integer correctionNumber = Integer.parseInt(groups.getOrDefault("correction", ""));
                if (parsedCorrection == null || correctionNumber == null || correctionNumber < 1) {
                    return null;
                }

                return new ParsedReleaseVersion(
                        parsedCorrection.getVersion(),
                        parsedCorrection.getBaseVersion(),
                        parsedCorrection.getChannel(),
                        parsedCorrection.getYear(),
                        parsedCorrection.getMonth(),
                        parsedCorrection.getDay(),
                        parsedCorrection.getBetaNumber(),
                        correctionNumber,
                        parsedCorrection.getDate()
                );
            } catch (NumberFormatException e) {
                return null;
            }
        }

        return null;
    }

    /**
     * Compares two release versions.
     *
     * @param left  First version to compare
     * @param right Second version to compare
     * @return -1 if left < right, 0 if equal, 1 if left > right, or null if either cannot be parsed
     */
    public static Integer compareReleaseVersions(String left, String right) {
        ParsedReleaseVersion parsedLeft = parseReleaseVersion(left);
        ParsedReleaseVersion parsedRight = parseReleaseVersion(right);

        if (parsedLeft == null || parsedRight == null) {
            return null;
        }

        long dateDelta = parsedLeft.getDate().toEpochDay() - parsedRight.getDate().toEpochDay();
        if (dateDelta != 0) {
            return Long.signum(dateDelta);
        }

        if (parsedLeft.getChannel() != parsedRight.getChannel()) {
            return parsedLeft.getChannel() == Channel.STABLE ? 1 : -1;
        }

        if (parsedLeft.getChannel() == Channel.BETA) {
            return Integer.compare(
                    parsedLeft.getBetaNumber() != null ? parsedLeft.getBetaNumber() : 0,
                    parsedRight.getBetaNumber() != null ? parsedRight.getBetaNumber() : 0
            );
        }

        return Integer.compare(
                parsedLeft.getCorrectionNumber() != null ? parsedLeft.getCorrectionNumber() : 0,
                parsedRight.getCorrectionNumber() != null ? parsedRight.getCorrectionNumber() : 0
        );
    }

    /**
     * Resolves the npm publish plan based on version and current beta version.
     *
     * @param version             The version to publish
     * @param currentBetaVersion The current beta version (optional)
     * @return An NpmPublishPlanResult with publishing instructions
     * @throws IllegalArgumentException If the version format is unsupported
     */
    public static NpmPublishPlanResult resolveNpmPublishPlan(String version, String currentBetaVersion) {
        ParsedReleaseVersion parsedVersion = parseReleaseVersion(version);
        if (parsedVersion == null) {
            throw new IllegalArgumentException("Unsupported release version \"" + version + "\".");
        }

        if (parsedVersion.getChannel() == Channel.BETA) {
            return new NpmPublishPlanResult(Channel.BETA, PublishTag.BETA, Collections.emptyList());
        }

        String normalizedCurrentBeta = currentBetaVersion != null ? currentBetaVersion.trim() : null;
        if (normalizedCurrentBeta != null && !normalizedCurrentBeta.isEmpty()) {
            Integer betaVsStable = compareReleaseVersions(normalizedCurrentBeta, version);
            if (betaVsStable != null && betaVsStable > 0) {
                return new NpmPublishPlanResult(Channel.STABLE, PublishTag.LATEST, Collections.emptyList());
            }
        }

        return new NpmPublishPlanResult(Channel.STABLE, PublishTag.LATEST, Arrays.asList(PublishTag.BETA));
    }

    /**
     * Overload for resolveNpmPublishPlan without currentBetaVersion parameter.
     */
    public static NpmPublishPlanResult resolveNpmPublishPlan(String version) {
        return resolveNpmPublishPlan(version, null);
    }

    /**
     * Resolves authentication information for npm dist tag mirroring.
     *
     * @param nodeAuthToken Optional node auth token
     * @param npmToken      Optional npm token
     * @return Authentication information
     */
    public static NpmDistTagMirrorAuth resolveNpmDistTagMirrorAuth(String nodeAuthToken, String npmToken) {
        if (nodeAuthToken != null && !nodeAuthToken.trim().isEmpty()) {
            return new NpmDistTagMirrorAuth(true, AuthSource.NODE_AUTH_TOKEN);
        }

        if (npmToken != null && !npmToken.trim().isEmpty()) {
            return new NpmDistTagMirrorAuth(true, AuthSource.NPM_TOKEN);
        }

        return new NpmDistTagMirrorAuth(false, AuthSource.NONE);
    }

    /**
     * Overload for resolveNpmDistTagMirrorAuth with optional parameters map.
     */
    public static NpmDistTagMirrorAuth resolveNpmDistTagMirrorAuth(Map<String, String> params) {
        String nodeAuthToken = params.get("nodeAuthToken");
        String npmToken = params.get("npmToken");
        return resolveNpmDistTagMirrorAuth(nodeAuthToken, npmToken);
    }

    /**
     * Determines if npm dist tag mirror authentication is required.
     *
     * @param mode           The npm publish mode
     * @param mirrorDistTags The list of mirror dist tags
     * @param hasAuth        Whether authentication is available
     * @return True if authentication is required, false otherwise
     */
    public static boolean shouldRequireNpmDistTagMirrorAuth(NpmPublishMode mode, List<String> mirrorDistTags, boolean hasAuth) {
        return mode == NpmPublishMode.PUBLISH &&
                mirrorDistTags.stream().anyMatch(tag -> tag != null && !tag.trim().isEmpty()) &&
                !hasAuth;
    }

    // Helper method to extract named groups from matcher
    private static Map<String, String> getNamedGroups(Matcher matcher) {
        return matcher.namedGroups().entrySet().stream()
                .collect(Collectors.toMap(
                        Map.Entry::getKey,
                        entry -> matcher.group(entry.getValue())
                ));
    }
}
