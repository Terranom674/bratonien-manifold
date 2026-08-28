import React from "react";
import PropTypes from "prop-types";
import EntityHero from "frontend/components/entity/Hero";
import EntityCollection from "frontend/components/entity/Collection/EntityCollection";
import CollectionNavigation from "frontend/components/CollectionNavigation";
import ContentBlockList from "frontend/components/content-block-list/List";
import { Warning } from "frontend/components/content-block/parts";
import Authorize from "hoc/Authorize";
import { useFromStore, useFrontendModeContext } from "hooks";

function Detail({ project }) {
  const { isStandalone } = useFrontendModeContext();
  const settings = useFromStore("settings", "select");
  const libraryDisabled = settings.attributes.general.libraryDisabled;

  return (
    <article className="bratonien-book-page">
      <header className="bratonien-book-page__hero">
        <EntityHero.Project entity={project} />
      </header>
      <div className="bratonien-book-page__body">
        <Authorize entity={project} ability="fullyRead" successBehavior="hide">
          <EntityCollection
            BodyComponent={() => <Warning.AccessDenied entity={project} />}
          />
        </Authorize>
        <ContentBlockList entity={project} />
      </div>
      {!isStandalone && !libraryDisabled && (
        <footer className="bratonien-book-page__navigation">
          <CollectionNavigation />
        </footer>
      )}
    </article>
  );
}

Detail.displayName = "Project.Detail";

Detail.propTypes = {
  project: PropTypes.object.isRequired
};

export default Detail;
