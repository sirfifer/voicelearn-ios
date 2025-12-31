
export interface Identifier {
    catalog?: string;
    value: string;
}

export interface VersionInfo {
    number: string;
    date?: string;
    changelog?: string;
}

export interface MediaItem {
    id: string;
    type: 'image' | 'diagram' | 'equation' | 'chart' | 'slideImage' | 'slideDeck' | 'video' | 'videoLecture';
    url: string;
    localPath?: string;
    title?: string;
    alt: string;
    caption?: string;
    mimeType?: string;
    dimensions?: { width: number; height: number };
    segmentTiming?: {
        startSegment: number;
        endSegment: number;
        displayMode: 'persistent' | 'highlight' | 'popup' | 'inline';
    };
}

export interface MediaCollection {
    embedded?: MediaItem[];
    reference?: MediaItem[];
}

export interface Segment {
    id: string;
    type: 'introduction' | 'lecture' | 'explanation' | 'example' | 'checkpoint' | 'transition' | 'summary' | 'conclusion';
    content: string;
    speakingNotes?: {
        pace?: string;
        emotionalTone?: string;
        emphasis?: string[];
        pauseAfter?: boolean;
        pauseDuration?: number;
    };
}

export interface Transcript {
    segments: Segment[];
}

export interface ContentNode {
    id: Identifier;
    title: string;
    type: 'curriculum' | 'unit' | 'module' | 'topic' | 'subtopic' | 'lesson' | 'section' | 'segment';
    orderIndex?: number;
    description?: string;
    transcript?: Transcript;
    media?: MediaCollection;
    children?: ContentNode[];
}

export interface Curriculum {
    umcf: "1.0.0";
    id: Identifier;
    title: string;
    version: VersionInfo;
    description?: string;
    locked?: boolean;
    content: ContentNode[];
}
