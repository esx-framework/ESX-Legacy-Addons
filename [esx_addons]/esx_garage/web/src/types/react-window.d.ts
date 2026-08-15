declare module 'react-window' {
  import { Component, CSSProperties, ReactNode } from 'react';

  export interface FixedSizeGridProps {
    children: (props: {
      columnIndex: number;
      rowIndex: number;
      style: CSSProperties;
      data?: any;
    }) => ReactNode;
    columnCount: number;
    columnWidth: number;
    height: number;
    rowCount: number;
    rowHeight: number;
    width: number;
    onScroll?: (params: { scrollTop: number; scrollLeft: number }) => void;
    itemData?: any;
  }

  export class FixedSizeGrid extends Component<FixedSizeGridProps> {}

  export class FixedSizeList extends Component<any> {}
  export class VariableSizeList extends Component<any> {}
  export class VariableSizeGrid extends Component<any> {}
}