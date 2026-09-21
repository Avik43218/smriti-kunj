import React from 'react';

// Line art PNG assets
import mountainsLight from '../assets/linearts/northeast_mountains_realistic_line_art_light_mode/screen.png';
import mountainsDark from '../assets/linearts/northeast_mountains_realistic_line_art_dark_mode/screen.png';
import riversLight from '../assets/linearts/northeast_rivers_waterfalls_realistic_line_art_light_mode/screen.png';
import riversDark from '../assets/linearts/northeast_rivers_waterfalls_realistic_line_art_dark_mode/screen.png';
import teaGardensLight from '../assets/linearts/northeast_tea_gardens_realistic_line_art_light_mode/screen.png';
import teaGardensDark from '../assets/linearts/northeast_tea_gardens_realistic_line_art_dark_mode/screen.png';
import workersLight from '../assets/linearts/realistic_northeast_tea_garden_workers_light_mode/screen.png';
import workersDark from '../assets/linearts/realistic_northeast_tea_garden_workers_dark_mode/screen.png';

const LINE_ARTS = {
  mountains: { light: mountainsLight, dark: mountainsDark, alt: 'Northeast Mountains Line Art' },
  rivers: { light: riversLight, dark: riversDark, alt: 'Northeast Rivers & Waterfalls Line Art' },
  teaGardens: { light: teaGardensLight, dark: teaGardensDark, alt: 'Northeast Tea Gardens Line Art' },
  workers: { light: workersLight, dark: workersDark, alt: 'Northeast Tea Garden Workers Line Art' },
};

/**
 * CardLineArt: Renders authentic regional line art watermarks inside prominent cards
 * with soothing, non-intrusive opacity across light and dark modes.
 */
export const CardLineArt = ({
  variant = 'mountains', // 'mountains' | 'rivers' | 'teaGardens' | 'workers'
  position = 'right', // 'right' | 'center' | 'left'
  className = '',
  imgClassName = '',
  opacityLight = 'opacity-30 sm:opacity-40',
  opacityDark = 'opacity-25 sm:opacity-35',
}) => {
  const art = LINE_ARTS[variant] || LINE_ARTS.mountains;

  let posClasses = 'right-0 top-0 bottom-0 justify-end';
  if (position === 'center') {
    posClasses = 'inset-0 justify-center';
  } else if (position === 'left') {
    posClasses = 'left-0 top-0 bottom-0 justify-start';
  }

  // Fade direction: for right-positioned art, fade from transparent-left → opaque-right
  // For left-positioned art, fade from opaque-left → transparent-right
  const fadeMask =
    position === 'left'
      ? 'linear-gradient(to left, transparent 0%, black 40%)'
      : 'linear-gradient(to right, transparent 0%, black 40%)';

  return (
    <div
      aria-hidden="true"
      className={`absolute ${posClasses} pointer-events-none select-none overflow-hidden flex items-center z-0 w-1/3 ${className}`}
      style={{
        WebkitMaskImage: fadeMask,
        maskImage: fadeMask,
      }}
    >
      {/* Light Mode Line Art */}
      <img
        src={art.light}
        alt=""
        aria-hidden="true"
        className={`dark:hidden h-full max-h-[180px] sm:max-h-[220px] w-full object-cover object-right transition-opacity duration-300 pointer-events-none mix-blend-multiply ${opacityLight} ${imgClassName}`}
      />

      {/* Dark Mode Line Art */}
      <img
        src={art.dark}
        alt=""
        aria-hidden="true"
        className={`hidden dark:block h-full max-h-[180px] sm:max-h-[220px] w-full object-cover object-right transition-opacity duration-300 pointer-events-none ${opacityDark} ${imgClassName}`}
      />
    </div>
  );
};

export default CardLineArt;
