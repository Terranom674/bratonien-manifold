import React, { useCallback, useEffect, useRef, useState } from "react";
import PropTypes from "prop-types";
import * as Styled from "./styles";

export default function Carousel({
  children,
  label,
  itemLabel = "Element",
  initialIndex = 0,
  variant = "full"
}) {
  const items = React.Children.toArray(children);
  const viewportRef = useRef(null);
  const [activeIndex, setActiveIndex] = useState(
    Math.min(Math.max(initialIndex, 0), Math.max(items.length - 1, 0))
  );

  const scrollToIndex = useCallback(
    index => {
      const viewport = viewportRef.current;
      if (!viewport || !items.length) return;

      const nextIndex = Math.min(Math.max(index, 0), items.length - 1);
      const target = viewport.children[nextIndex];
      if (!target) return;

      viewport.scrollTo({ left: target.offsetLeft, behavior: "smooth" });
      setActiveIndex(nextIndex);
    },
    [items.length]
  );

  const updateFromScroll = useCallback(() => {
    const viewport = viewportRef.current;
    if (!viewport || !viewport.children.length) return;

    const scrollLeft = viewport.scrollLeft;
    let closestIndex = 0;
    let closestDistance = Number.POSITIVE_INFINITY;

    Array.from(viewport.children).forEach((child, index) => {
      const distance = Math.abs(child.offsetLeft - scrollLeft);
      if (distance < closestDistance) {
        closestDistance = distance;
        closestIndex = index;
      }
    });

    setActiveIndex(closestIndex);
  }, []);

  useEffect(() => {
    const viewport = viewportRef.current;
    if (!viewport) return undefined;

    let frame = null;
    const onScroll = () => {
      if (frame) cancelAnimationFrame(frame);
      frame = requestAnimationFrame(updateFromScroll);
    };

    viewport.addEventListener("scroll", onScroll, { passive: true });
    return () => {
      if (frame) cancelAnimationFrame(frame);
      viewport.removeEventListener("scroll", onScroll);
    };
  }, [updateFromScroll]);

  useEffect(() => {
    if (!items.length) return;
    const safeIndex = Math.min(activeIndex, items.length - 1);
    if (safeIndex !== activeIndex) setActiveIndex(safeIndex);
  }, [activeIndex, items.length]);

  const handleKeyDown = event => {
    if (event.key === "ArrowRight" || event.key === "PageDown") {
      event.preventDefault();
      scrollToIndex(activeIndex + 1);
    } else if (event.key === "ArrowLeft" || event.key === "PageUp") {
      event.preventDefault();
      scrollToIndex(activeIndex - 1);
    } else if (event.key === "Home") {
      event.preventDefault();
      scrollToIndex(0);
    } else if (event.key === "End") {
      event.preventDefault();
      scrollToIndex(items.length - 1);
    }
  };

  if (!items.length) return null;

  return (
    <Styled.Root
      role="region"
      aria-roledescription="Karussell"
      aria-label={label}
      data-variant={variant}
    >
      <Styled.Viewport
        ref={viewportRef}
        tabIndex={0}
        onKeyDown={handleKeyDown}
        $variant={variant}
      >
        {items.map((item, index) => (
          <Styled.Slide
            key={item.key ?? index}
            aria-roledescription="Folie"
            aria-label={`${itemLabel} ${index + 1} von ${items.length}`}
            data-active={index === activeIndex}
          >
            {item}
          </Styled.Slide>
        ))}
      </Styled.Viewport>

      {items.length > 1 && (
        <Styled.Controls>
          <Styled.Button
            type="button"
            onClick={() => scrollToIndex(activeIndex - 1)}
            disabled={activeIndex === 0}
            aria-label="Vorheriges Element"
          >
            <span aria-hidden="true">‹</span>
          </Styled.Button>
          <Styled.Position aria-live="polite">
            {activeIndex + 1} / {items.length}
          </Styled.Position>
          <Styled.Button
            type="button"
            onClick={() => scrollToIndex(activeIndex + 1)}
            disabled={activeIndex === items.length - 1}
            aria-label="Nächstes Element"
          >
            <span aria-hidden="true">›</span>
          </Styled.Button>
        </Styled.Controls>
      )}
    </Styled.Root>
  );
}

Carousel.propTypes = {
  children: PropTypes.node,
  label: PropTypes.string.isRequired,
  itemLabel: PropTypes.string,
  initialIndex: PropTypes.number,
  variant: PropTypes.oneOf(["full", "cards"])
};
