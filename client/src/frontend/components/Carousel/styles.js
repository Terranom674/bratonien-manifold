import styled from "@emotion/styled";

export const Root = styled.section`
  --carousel-gap: clamp(14px, 2vw, 24px);
  position: relative;
  width: 100%;
`;

export const Viewport = styled.div`
  display: grid;
  grid-auto-flow: column;
  grid-auto-columns: ${({ $variant }) =>
    $variant === "cards" ? "minmax(240px, 31%)" : "100%"};
  gap: var(--carousel-gap);
  width: 100%;
  overflow-x: auto;
  overflow-y: hidden;
  overscroll-behavior-inline: contain;
  scroll-snap-type: inline mandatory;
  scroll-behavior: smooth;
  scrollbar-width: none;
  touch-action: pan-x pan-y;
  padding-block: 4px;

  &::-webkit-scrollbar {
    display: none;
  }

  &:focus-visible {
    outline: 2px solid var(--focus-color);
    outline-offset: 4px;
  }

  @media (max-width: 900px) {
    grid-auto-columns: ${({ $variant }) =>
      $variant === "cards" ? "minmax(230px, 47%)" : "100%"};
  }

  @media (max-width: 600px) {
    grid-auto-columns: ${({ $variant }) =>
      $variant === "cards" ? "minmax(220px, 82%)" : "100%"};
  }

  @media (prefers-reduced-motion: reduce) {
    scroll-behavior: auto;
  }
`;

export const Slide = styled.div`
  min-width: 0;
  scroll-snap-align: start;
  scroll-snap-stop: always;
  opacity: 0.72;
  transform: scale(0.985);
  transform-origin: center;
  transition: opacity 180ms ease, transform 180ms ease;

  &[data-active="true"] {
    opacity: 1;
    transform: scale(1);
  }

  > * {
    height: 100%;
  }

  @media (prefers-reduced-motion: reduce) {
    transition: none;
    transform: none;
  }
`;

export const Controls = styled.div`
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  margin-top: 14px;
`;

export const Button = styled.button`
  display: inline-grid;
  place-items: center;
  width: 42px;
  height: 42px;
  padding: 0;
  font-size: 30px;
  line-height: 1;
  color: var(--br-dark);
  background: var(--br-brown);
  border: 1px solid var(--br-brown-border);
  cursor: pointer;

  &:hover,
  &:focus-visible {
    color: var(--br-gold-light);
    background: var(--br-blue);
    border-color: var(--br-gold);
  }

  &:disabled {
    cursor: default;
    opacity: 0.35;
  }
`;

export const Position = styled.span`
  min-width: 72px;
  color: var(--br-text);
  text-align: center;
  font-variant-numeric: tabular-nums;
`;
