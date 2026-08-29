import React, { useCallback } from "react";
import PropTypes from "prop-types";
import lh from "helpers/linkHandler";
import { useTranslation } from "react-i18next";
import EntityThumbnail from "global/components/atomic/EntityThumbnail";
import Carousel from "frontend/components/Carousel";
import { FooterLink, ProjectCollectionIcon } from "../parts";
import EntityCollection from "../EntityCollection";
import { getHeroImage, getHeaderLayout } from "../helpers";

function ProjectCollectionSummaryEntityCollection({
  projectCollection,
  paginationProps,
  filterProps,
  limit,
  ...passThroughProps
}) {
  const { t } = useTranslation();

  const {
    title,
    slug,
    descriptionFormatted: description,
    shortDescriptionFormatted: shortDescription
  } = projectCollection.attributes;

  const mapProjects = useCallback(collection => {
    if (!Array.isArray(collection.relationships.collectionProjects)) return [];
    return collection.relationships.collectionProjects.map(
      cp => cp.relationships.project
    );
  }, []);

  const adjustedLimit = typeof limit === "number" && limit >= 0 ? limit : 12;
  const projects = mapProjects(projectCollection).slice(0, adjustedLimit);
  const headerLayout = getHeaderLayout(projectCollection);
  const image = getHeroImage(headerLayout, projectCollection);
  const imageAlt = projectCollection.attributes.heroAltText;
  const totalprojectCount = projectCollection.attributes.projectsCount;

  return (
    <EntityCollection
      title={title}
      description={shortDescription || description}
      IconComponent={ProjectCollectionIcon}
      iconProps={{ collection: projectCollection }}
      image={image}
      imageAlt={imageAlt}
      headerLayout={headerLayout}
      headerWidth="100%"
      headerLink={lh.link("frontendProjectCollection", slug)}
      BodyComponent={() =>
        !!projects?.length && (
          <Carousel
            label={title}
            itemLabel={t("glossary.project_one")}
            variant="cards"
          >
            {projects.map(item => (
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
      FooterComponent={() =>
        totalprojectCount > adjustedLimit && (
          <FooterLink
            to={lh.link("frontendProjectCollection", slug)}
            label={t("navigation.see_full_collection")}
          />
        )
      }
      {...passThroughProps}
    />
  );
}

ProjectCollectionSummaryEntityCollection.displayName =
  "Frontend.Entity.Collection.ProjectCollectionSummary";

ProjectCollectionSummaryEntityCollection.propTypes = {
  projectCollection: PropTypes.object.isRequired,
  projects: PropTypes.arrayOf(PropTypes.object),
  projectsMeta: PropTypes.object,
  limit: PropTypes.number
};

export default ProjectCollectionSummaryEntityCollection;
