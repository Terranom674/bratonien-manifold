import React from "react";
import PropTypes from "prop-types";
import { useTranslation } from "react-i18next";
import lh from "helpers/linkHandler";
import EntityThumbnail from "global/components/atomic/EntityThumbnail";
import Carousel from "frontend/components/Carousel";
import { FooterLink, ProjectCollectionIcon } from "../parts";
import EntityCollection from "../EntityCollection";
import { getHeroImage, getHeaderLayout } from "../helpers";

function JournalSummaryEntityCollection({
  journal,
  paginationProps,
  filterProps,
  limit = 4,
  ...passThroughProps
}) {
  const { t } = useTranslation();
  if (!journal) return null;

  const { title, descriptionFormatted: description, slug } =
    journal.attributes ?? {};
  const issues = journal.relationships?.recentJournalIssues ?? [];
  const headerLayout = getHeaderLayout(journal);
  const image = getHeroImage(headerLayout, journal);
  const imageAlt = journal.attributes.heroAltText;

  const totalIssueCount = journal.attributes?.journalIssuesCount;
  const footerLinkText =
    totalIssueCount > limit
      ? t("navigation.see_all_issues")
      : t("navigation.visit_page");

  return (
    <EntityCollection
      title={title}
      description={description}
      IconComponent={ProjectCollectionIcon}
      iconProps={{ collection: journal }}
      image={image}
      imageAlt={imageAlt}
      headerLayout={headerLayout}
      headerLink={lh.link("frontendJournal", slug)}
      BodyComponent={() =>
        !!issues?.length && (
          <Carousel
            label={title}
            itemLabel={t("glossary.issue_truncated_one")}
            variant="cards"
          >
            {issues.map(item => (
              <EntityThumbnail
                key={item.id}
                entity={item}
                stack
                isListItem={false}
              />
            ))}
          </Carousel>
        )
      }
      FooterComponent={() => (
        <FooterLink
          to={lh.link("frontendJournal", slug)}
          label={footerLinkText}
          tabIndex={-1}
        />
      )}
      {...passThroughProps}
    />
  );
}

JournalSummaryEntityCollection.displayName =
  "Frontend.Entity.Collection.JournalSummary";

JournalSummaryEntityCollection.propTypes = {
  journal: PropTypes.object.isRequired,
  projects: PropTypes.arrayOf(PropTypes.object),
  projectsMeta: PropTypes.object,
  limit: PropTypes.number
};

export default JournalSummaryEntityCollection;
