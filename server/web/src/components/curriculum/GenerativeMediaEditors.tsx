/**
 * Generative Media Editor Components
 *
 * Provides editors for:
 * - Diagrams (Mermaid, Graphviz, PlantUML, D2)
 * - Formulas (LaTeX)
 * - Maps (geographic with markers, routes, regions)
 */

import React, { useState, useCallback, useEffect } from 'react';
import {
  GitBranch,
  FunctionSquare as FunctionIcon,
  Map,
  Play,
  Loader2,
  AlertCircle,
  CheckCircle,
  X,
  Plus,
  Trash2,
  MapPin,
} from 'lucide-react';
import { clsx } from 'clsx';
import {
  validateDiagram,
  renderDiagram,
  validateFormula,
  renderFormula,
  renderMap,
  getMapStyles,
} from '@/lib/api-client';
import type {
  DiagramFormat,
  MapStyleOption,
  MapMarkerSpec,
  MapRouteSpec,
  MapRegionSpec,
} from '@/types';

// =============================================================================
// Diagram Editor
// =============================================================================

interface DiagramEditorProps {
  initialCode?: string;
  initialFormat?: DiagramFormat;
  onSave: (code: string, format: DiagramFormat, renderedData?: string) => void;
  onClose: () => void;
}

const DIAGRAM_FORMATS: { id: DiagramFormat; name: string; placeholder: string }[] = [
  {
    id: 'mermaid',
    name: 'Mermaid',
    placeholder: `graph LR
  A[Start] --> B{Decision}
  B -->|Yes| C[Action]
  B -->|No| D[End]`,
  },
  {
    id: 'graphviz',
    name: 'Graphviz (DOT)',
    placeholder: `digraph G {
  A -> B;
  B -> C;
  C -> A;
}`,
  },
  {
    id: 'plantuml',
    name: 'PlantUML',
    placeholder: `@startuml
Alice -> Bob: Hello
Bob --> Alice: Hi!
@enduml`,
  },
  {
    id: 'd2',
    name: 'D2',
    placeholder: `x -> y: Hello World`,
  },
];

export const DiagramEditor: React.FC<DiagramEditorProps> = ({
  initialCode = '',
  initialFormat = 'mermaid',
  onSave,
  onClose,
}) => {
  const [code, setCode] = useState(initialCode);
  const [format, setFormat] = useState<DiagramFormat>(initialFormat);
  const [validating, setValidating] = useState(false);
  const [rendering, setRendering] = useState(false);
  const [errors, setErrors] = useState<string[]>([]);
  const [preview, setPreview] = useState<string | null>(null);
  const [previewMimeType, setPreviewMimeType] = useState<string>('image/svg+xml');

  const handleValidate = useCallback(async () => {
    if (!code.trim()) {
      setErrors(['Please enter diagram code']);
      return;
    }
    setValidating(true);
    setErrors([]);
    try {
      const result = await validateDiagram({ format, code });
      if (!result.valid) {
        setErrors(result.errors);
      }
    } catch (e) {
      setErrors(['Validation failed: ' + (e instanceof Error ? e.message : 'Unknown error')]);
    } finally {
      setValidating(false);
    }
  }, [code, format]);

  const handleRender = useCallback(async () => {
    if (!code.trim()) {
      setErrors(['Please enter diagram code']);
      return;
    }
    setRendering(true);
    setErrors([]);
    try {
      const result = await renderDiagram({ format, code, outputFormat: 'svg' });
      if (result.success && result.data) {
        setPreview(result.data);
        setPreviewMimeType(result.mimeType || 'image/svg+xml');
      } else {
        setErrors(result.validationErrors || [result.error || 'Rendering failed']);
      }
    } catch (e) {
      setErrors(['Rendering failed: ' + (e instanceof Error ? e.message : 'Unknown error')]);
    } finally {
      setRendering(false);
    }
  }, [code, format]);

  const handleSave = () => {
    onSave(code, format, preview || undefined);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm animate-in">
      <div className="bg-slate-900 border border-slate-700 rounded-xl shadow-2xl w-full max-w-5xl max-h-[90vh] flex flex-col overflow-hidden">
        {/* Header */}
        <div className="p-4 border-b border-slate-800 flex justify-between items-center bg-slate-900/50">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-purple-500/10 rounded-lg border border-purple-500/20">
              <GitBranch className="text-purple-400" size={20} />
            </div>
            <div>
              <h2 className="text-lg font-semibold text-white">Create Diagram</h2>
              <p className="text-sm text-slate-400">Write diagram code and preview the result</p>
            </div>
          </div>
          <button onClick={onClose} className="p-2 hover:bg-slate-800 rounded-full transition-colors text-slate-400 hover:text-white">
            <X size={20} />
          </button>
        </div>

        <div className="flex-1 flex overflow-hidden">
          {/* Editor Panel */}
          <div className="flex-1 flex flex-col border-r border-slate-800">
            {/* Format Selector */}
            <div className="p-3 border-b border-slate-800 flex gap-2">
              {DIAGRAM_FORMATS.map((f) => (
                <button
                  key={f.id}
                  onClick={() => {
                    setFormat(f.id);
                    if (!code.trim()) setCode(f.placeholder);
                  }}
                  className={clsx(
                    'px-3 py-1.5 rounded-lg text-sm font-medium transition-all',
                    format === f.id
                      ? 'bg-purple-600 text-white'
                      : 'bg-slate-800 text-slate-400 hover:text-white hover:bg-slate-700'
                  )}
                >
                  {f.name}
                </button>
              ))}
            </div>

            {/* Code Editor */}
            <div className="flex-1 p-4">
              <textarea
                value={code}
                onChange={(e) => setCode(e.target.value)}
                placeholder={DIAGRAM_FORMATS.find((f) => f.id === format)?.placeholder}
                className="w-full h-full bg-slate-950 border border-slate-700 rounded-lg p-4 text-sm font-mono text-slate-200 focus:ring-2 focus:ring-purple-500 focus:outline-none resize-none"
                spellCheck={false}
              />
            </div>

            {/* Errors */}
            {errors.length > 0 && (
              <div className="px-4 pb-4">
                <div className="bg-red-500/10 border border-red-500/20 rounded-lg p-3">
                  <div className="flex items-center gap-2 text-red-400 text-sm">
                    <AlertCircle size={16} />
                    <span className="font-medium">Errors:</span>
                  </div>
                  <ul className="mt-2 space-y-1 text-sm text-red-300">
                    {errors.map((e, i) => (
                      <li key={i}>• {e}</li>
                    ))}
                  </ul>
                </div>
              </div>
            )}

            {/* Actions */}
            <div className="p-4 border-t border-slate-800 flex gap-3">
              <button
                onClick={handleValidate}
                disabled={validating}
                className="px-4 py-2 bg-slate-700 hover:bg-slate-600 text-white rounded-lg transition-all flex items-center gap-2 disabled:opacity-50"
              >
                {validating ? <Loader2 size={16} className="animate-spin" /> : <CheckCircle size={16} />}
                Validate
              </button>
              <button
                onClick={handleRender}
                disabled={rendering}
                className="px-4 py-2 bg-purple-600 hover:bg-purple-500 text-white rounded-lg transition-all flex items-center gap-2 disabled:opacity-50"
              >
                {rendering ? <Loader2 size={16} className="animate-spin" /> : <Play size={16} />}
                Render Preview
              </button>
            </div>
          </div>

          {/* Preview Panel */}
          <div className="w-1/2 flex flex-col bg-slate-950">
            <div className="p-3 border-b border-slate-800 text-sm font-medium text-slate-400">
              Preview
            </div>
            <div className="flex-1 flex items-center justify-center p-4 overflow-auto">
              {preview ? (
                <img
                  src={`data:${previewMimeType};base64,${preview}`}
                  alt="Diagram preview"
                  className="max-w-full max-h-full object-contain"
                />
              ) : (
                <div className="text-slate-500 text-center">
                  <GitBranch size={48} className="mx-auto mb-3 opacity-30" />
                  <p>Click Render Preview to see your diagram</p>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="p-4 border-t border-slate-800 flex justify-end gap-3">
          <button
            onClick={onClose}
            className="px-4 py-2 bg-slate-700 hover:bg-slate-600 text-white rounded-lg transition-all"
          >
            Cancel
          </button>
          <button
            onClick={handleSave}
            disabled={!code.trim()}
            className="px-4 py-2 bg-indigo-600 hover:bg-indigo-500 text-white rounded-lg transition-all disabled:opacity-50"
          >
            Add Diagram
          </button>
        </div>
      </div>
    </div>
  );
};

// =============================================================================
// Formula Editor
// =============================================================================

interface FormulaEditorProps {
  initialLatex?: string;
  onSave: (latex: string, renderedData?: string) => void;
  onClose: () => void;
}

const FORMULA_EXAMPLES = [
  { name: 'Quadratic Formula', latex: 'x = \\frac{-b \\pm \\sqrt{b^2-4ac}}{2a}' },
  { name: 'Pythagorean Theorem', latex: 'a^2 + b^2 = c^2' },
  { name: 'Euler\'s Identity', latex: 'e^{i\\pi} + 1 = 0' },
  { name: 'Derivative', latex: '\\frac{d}{dx}f(x) = \\lim_{h \\to 0} \\frac{f(x+h) - f(x)}{h}' },
  { name: 'Integral', latex: '\\int_a^b f(x)\\,dx = F(b) - F(a)' },
  { name: 'Sum', latex: '\\sum_{i=1}^{n} i = \\frac{n(n+1)}{2}' },
];

export const FormulaEditor: React.FC<FormulaEditorProps> = ({
  initialLatex = '',
  onSave,
  onClose,
}) => {
  const [latex, setLatex] = useState(initialLatex);
  const [validating, setValidating] = useState(false);
  const [rendering, setRendering] = useState(false);
  const [errors, setErrors] = useState<string[]>([]);
  const [warnings, setWarnings] = useState<string[]>([]);
  const [preview, setPreview] = useState<string | null>(null);

  const handleValidate = useCallback(async () => {
    if (!latex.trim()) {
      setErrors(['Please enter a LaTeX formula']);
      return;
    }
    setValidating(true);
    setErrors([]);
    setWarnings([]);
    try {
      const result = await validateFormula({ latex });
      if (!result.valid) {
        setErrors(result.errors);
      }
      if (result.warnings.length > 0) {
        setWarnings(result.warnings);
      }
    } catch (e) {
      setErrors(['Validation failed: ' + (e instanceof Error ? e.message : 'Unknown error')]);
    } finally {
      setValidating(false);
    }
  }, [latex]);

  const handleRender = useCallback(async () => {
    if (!latex.trim()) {
      setErrors(['Please enter a LaTeX formula']);
      return;
    }
    setRendering(true);
    setErrors([]);
    try {
      const result = await renderFormula({ latex, outputFormat: 'svg', displayMode: true });
      if (result.success && result.data) {
        setPreview(result.data);
        if (result.warnings) {
          setWarnings(result.warnings);
        }
      } else {
        setErrors(result.validationErrors || [result.error || 'Rendering failed']);
      }
    } catch (e) {
      setErrors(['Rendering failed: ' + (e instanceof Error ? e.message : 'Unknown error')]);
    } finally {
      setRendering(false);
    }
  }, [latex]);

  const handleSave = () => {
    onSave(latex, preview || undefined);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm animate-in">
      <div className="bg-slate-900 border border-slate-700 rounded-xl shadow-2xl w-full max-w-4xl max-h-[90vh] flex flex-col overflow-hidden">
        {/* Header */}
        <div className="p-4 border-b border-slate-800 flex justify-between items-center bg-slate-900/50">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-blue-500/10 rounded-lg border border-blue-500/20">
              <FunctionIcon className="text-blue-400" size={20} />
            </div>
            <div>
              <h2 className="text-lg font-semibold text-white">Create Formula</h2>
              <p className="text-sm text-slate-400">Write LaTeX and preview the rendered formula</p>
            </div>
          </div>
          <button onClick={onClose} className="p-2 hover:bg-slate-800 rounded-full transition-colors text-slate-400 hover:text-white">
            <X size={20} />
          </button>
        </div>

        <div className="flex-1 flex flex-col overflow-hidden p-4 gap-4">
          {/* Examples */}
          <div className="flex flex-wrap gap-2">
            <span className="text-xs text-slate-500 py-1">Examples:</span>
            {FORMULA_EXAMPLES.map((ex) => (
              <button
                key={ex.name}
                onClick={() => setLatex(ex.latex)}
                className="px-2 py-1 text-xs bg-slate-800 hover:bg-slate-700 text-slate-300 rounded transition-all"
              >
                {ex.name}
              </button>
            ))}
          </div>

          {/* LaTeX Input */}
          <div className="flex-1 flex flex-col gap-2">
            <label className="text-sm font-medium text-slate-300">LaTeX Formula</label>
            <textarea
              value={latex}
              onChange={(e) => setLatex(e.target.value)}
              placeholder="Enter LaTeX formula, e.g., x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}"
              className="flex-1 bg-slate-950 border border-slate-700 rounded-lg p-4 text-sm font-mono text-slate-200 focus:ring-2 focus:ring-blue-500 focus:outline-none resize-none min-h-[100px]"
              spellCheck={false}
            />
          </div>

          {/* Preview */}
          <div className="bg-slate-950 border border-slate-700 rounded-lg p-6 min-h-[120px] flex items-center justify-center">
            {preview ? (
              <img
                src={`data:image/svg+xml;base64,${preview}`}
                alt="Formula preview"
                className="max-w-full max-h-[200px] object-contain"
              />
            ) : (
              <div className="text-slate-500 text-center">
                <FunctionIcon size={32} className="mx-auto mb-2 opacity-30" />
                <p className="text-sm">Click Render Preview to see your formula</p>
              </div>
            )}
          </div>

          {/* Errors/Warnings */}
          {errors.length > 0 && (
            <div className="bg-red-500/10 border border-red-500/20 rounded-lg p-3">
              <div className="flex items-center gap-2 text-red-400 text-sm">
                <AlertCircle size={16} />
                <span className="font-medium">Errors:</span>
              </div>
              <ul className="mt-1 space-y-1 text-sm text-red-300">
                {errors.map((e, i) => (
                  <li key={i}>• {e}</li>
                ))}
              </ul>
            </div>
          )}
          {warnings.length > 0 && (
            <div className="bg-yellow-500/10 border border-yellow-500/20 rounded-lg p-3">
              <div className="flex items-center gap-2 text-yellow-400 text-sm">
                <AlertCircle size={16} />
                <span className="font-medium">Warnings:</span>
              </div>
              <ul className="mt-1 space-y-1 text-sm text-yellow-300">
                {warnings.map((w, i) => (
                  <li key={i}>• {w}</li>
                ))}
              </ul>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="p-4 border-t border-slate-800 flex justify-between">
          <div className="flex gap-3">
            <button
              onClick={handleValidate}
              disabled={validating}
              className="px-4 py-2 bg-slate-700 hover:bg-slate-600 text-white rounded-lg transition-all flex items-center gap-2 disabled:opacity-50"
            >
              {validating ? <Loader2 size={16} className="animate-spin" /> : <CheckCircle size={16} />}
              Validate
            </button>
            <button
              onClick={handleRender}
              disabled={rendering}
              className="px-4 py-2 bg-blue-600 hover:bg-blue-500 text-white rounded-lg transition-all flex items-center gap-2 disabled:opacity-50"
            >
              {rendering ? <Loader2 size={16} className="animate-spin" /> : <Play size={16} />}
              Render Preview
            </button>
          </div>
          <div className="flex gap-3">
            <button
              onClick={onClose}
              className="px-4 py-2 bg-slate-700 hover:bg-slate-600 text-white rounded-lg transition-all"
            >
              Cancel
            </button>
            <button
              onClick={handleSave}
              disabled={!latex.trim()}
              className="px-4 py-2 bg-indigo-600 hover:bg-indigo-500 text-white rounded-lg transition-all disabled:opacity-50"
            >
              Add Formula
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

// =============================================================================
// Map Editor
// =============================================================================

interface MapEditorProps {
  initialSpec?: Partial<{
    title: string;
    center: { latitude: number; longitude: number };
    zoom: number;
    style: MapStyleOption;
    markers: MapMarkerSpec[];
    routes: MapRouteSpec[];
    regions: MapRegionSpec[];
  }>;
  onSave: (spec: {
    title: string;
    center: { latitude: number; longitude: number };
    zoom: number;
    style: MapStyleOption;
    markers: MapMarkerSpec[];
    routes: MapRouteSpec[];
    regions: MapRegionSpec[];
  }, renderedData?: string) => void;
  onClose: () => void;
}

export const MapEditor: React.FC<MapEditorProps> = ({
  initialSpec,
  onSave,
  onClose,
}) => {
  const [title, setTitle] = useState(initialSpec?.title || '');
  const [latitude, setLatitude] = useState(initialSpec?.center?.latitude?.toString() || '43.0');
  const [longitude, setLongitude] = useState(initialSpec?.center?.longitude?.toString() || '12.0');
  const [zoom, setZoom] = useState(initialSpec?.zoom?.toString() || '6');
  const [style, setStyle] = useState<MapStyleOption>(initialSpec?.style || 'educational');
  const [markers, setMarkers] = useState<MapMarkerSpec[]>(initialSpec?.markers || []);
  const [rendering, setRendering] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [styles, setStyles] = useState<{ id: MapStyleOption; name: string; description: string }[]>([]);

  // Load available styles
  useEffect(() => {
    getMapStyles().then((res) => {
      if (res.success) {
        setStyles(res.styles);
      }
    });
  }, []);

  const handleAddMarker = () => {
    setMarkers([
      ...markers,
      {
        latitude: parseFloat(latitude) || 0,
        longitude: parseFloat(longitude) || 0,
        label: `Marker ${markers.length + 1}`,
      },
    ]);
  };

  const handleRemoveMarker = (index: number) => {
    setMarkers(markers.filter((_, i) => i !== index));
  };

  const handleMarkerChange = (index: number, field: keyof MapMarkerSpec, value: string | number) => {
    setMarkers(
      markers.map((m, i) =>
        i === index ? { ...m, [field]: value } : m
      )
    );
  };

  const handleRender = useCallback(async () => {
    setRendering(true);
    setError(null);
    try {
      const result = await renderMap({
        title: title || 'Map',
        center: {
          latitude: parseFloat(latitude) || 0,
          longitude: parseFloat(longitude) || 0,
        },
        zoom: parseInt(zoom) || 6,
        style,
        markers,
        width: 600,
        height: 400,
      });
      if (result.success && result.data) {
        setPreview(result.data);
      } else {
        setError(result.error || 'Rendering failed');
      }
    } catch (e) {
      setError('Rendering failed: ' + (e instanceof Error ? e.message : 'Unknown error'));
    } finally {
      setRendering(false);
    }
  }, [title, latitude, longitude, zoom, style, markers]);

  const handleSave = () => {
    onSave(
      {
        title: title || 'Map',
        center: {
          latitude: parseFloat(latitude) || 0,
          longitude: parseFloat(longitude) || 0,
        },
        zoom: parseInt(zoom) || 6,
        style,
        markers,
        routes: [],
        regions: [],
      },
      preview || undefined
    );
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm animate-in">
      <div className="bg-slate-900 border border-slate-700 rounded-xl shadow-2xl w-full max-w-5xl max-h-[90vh] flex flex-col overflow-hidden">
        {/* Header */}
        <div className="p-4 border-b border-slate-800 flex justify-between items-center bg-slate-900/50">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-green-500/10 rounded-lg border border-green-500/20">
              <Map className="text-green-400" size={20} />
            </div>
            <div>
              <h2 className="text-lg font-semibold text-white">Create Map</h2>
              <p className="text-sm text-slate-400">Configure geographic content with markers and routes</p>
            </div>
          </div>
          <button onClick={onClose} className="p-2 hover:bg-slate-800 rounded-full transition-colors text-slate-400 hover:text-white">
            <X size={20} />
          </button>
        </div>

        <div className="flex-1 flex overflow-hidden">
          {/* Settings Panel */}
          <div className="w-1/2 flex flex-col border-r border-slate-800 overflow-y-auto">
            <div className="p-4 space-y-4">
              {/* Title */}
              <div>
                <label className="text-sm font-medium text-slate-300 block mb-1">Title</label>
                <input
                  type="text"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  placeholder="e.g., Italian City-States"
                  className="w-full bg-slate-950 border border-slate-700 rounded-lg px-3 py-2 text-sm text-slate-200 focus:ring-2 focus:ring-green-500 focus:outline-none"
                />
              </div>

              {/* Center & Zoom */}
              <div className="grid grid-cols-3 gap-3">
                <div>
                  <label className="text-sm font-medium text-slate-300 block mb-1">Latitude</label>
                  <input
                    type="number"
                    step="0.1"
                    value={latitude}
                    onChange={(e) => setLatitude(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-700 rounded-lg px-3 py-2 text-sm text-slate-200 focus:ring-2 focus:ring-green-500 focus:outline-none"
                  />
                </div>
                <div>
                  <label className="text-sm font-medium text-slate-300 block mb-1">Longitude</label>
                  <input
                    type="number"
                    step="0.1"
                    value={longitude}
                    onChange={(e) => setLongitude(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-700 rounded-lg px-3 py-2 text-sm text-slate-200 focus:ring-2 focus:ring-green-500 focus:outline-none"
                  />
                </div>
                <div>
                  <label className="text-sm font-medium text-slate-300 block mb-1">Zoom (1-18)</label>
                  <input
                    type="number"
                    min="1"
                    max="18"
                    value={zoom}
                    onChange={(e) => setZoom(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-700 rounded-lg px-3 py-2 text-sm text-slate-200 focus:ring-2 focus:ring-green-500 focus:outline-none"
                  />
                </div>
              </div>

              {/* Style */}
              <div>
                <label className="text-sm font-medium text-slate-300 block mb-2">Map Style</label>
                <div className="grid grid-cols-3 gap-2">
                  {styles.map((s) => (
                    <button
                      key={s.id}
                      onClick={() => setStyle(s.id)}
                      className={clsx(
                        'px-3 py-2 rounded-lg text-xs font-medium transition-all text-left',
                        style === s.id
                          ? 'bg-green-600 text-white'
                          : 'bg-slate-800 text-slate-400 hover:text-white hover:bg-slate-700'
                      )}
                    >
                      <div className="font-semibold">{s.name}</div>
                      <div className="opacity-70 text-[10px]">{s.description}</div>
                    </button>
                  ))}
                </div>
              </div>

              {/* Markers */}
              <div>
                <div className="flex justify-between items-center mb-2">
                  <label className="text-sm font-medium text-slate-300 flex items-center gap-2">
                    <MapPin size={14} />
                    Markers
                  </label>
                  <button
                    onClick={handleAddMarker}
                    className="px-2 py-1 text-xs bg-slate-800 hover:bg-slate-700 text-slate-300 rounded flex items-center gap-1"
                  >
                    <Plus size={12} />
                    Add
                  </button>
                </div>
                <div className="space-y-2 max-h-[200px] overflow-y-auto">
                  {markers.length === 0 ? (
                    <div className="text-xs text-slate-500 py-2">No markers yet. Click Add to create one.</div>
                  ) : (
                    markers.map((marker, i) => (
                      <div key={i} className="bg-slate-800 rounded-lg p-2 space-y-2">
                        <div className="flex justify-between items-center">
                          <span className="text-xs text-slate-400">Marker {i + 1}</span>
                          <button
                            onClick={() => handleRemoveMarker(i)}
                            className="p-1 text-red-400 hover:text-red-300"
                          >
                            <Trash2 size={12} />
                          </button>
                        </div>
                        <input
                          type="text"
                          value={marker.label}
                          onChange={(e) => handleMarkerChange(i, 'label', e.target.value)}
                          placeholder="Label"
                          className="w-full bg-slate-900 border border-slate-700 rounded px-2 py-1 text-xs text-slate-200"
                        />
                        <div className="grid grid-cols-2 gap-2">
                          <input
                            type="number"
                            step="0.1"
                            value={marker.latitude}
                            onChange={(e) => handleMarkerChange(i, 'latitude', parseFloat(e.target.value))}
                            placeholder="Lat"
                            className="w-full bg-slate-900 border border-slate-700 rounded px-2 py-1 text-xs text-slate-200"
                          />
                          <input
                            type="number"
                            step="0.1"
                            value={marker.longitude}
                            onChange={(e) => handleMarkerChange(i, 'longitude', parseFloat(e.target.value))}
                            placeholder="Lon"
                            className="w-full bg-slate-900 border border-slate-700 rounded px-2 py-1 text-xs text-slate-200"
                          />
                        </div>
                      </div>
                    ))
                  )}
                </div>
              </div>
            </div>

            {/* Render Button */}
            <div className="p-4 border-t border-slate-800 mt-auto">
              <button
                onClick={handleRender}
                disabled={rendering}
                className="w-full px-4 py-2 bg-green-600 hover:bg-green-500 text-white rounded-lg transition-all flex items-center justify-center gap-2 disabled:opacity-50"
              >
                {rendering ? <Loader2 size={16} className="animate-spin" /> : <Play size={16} />}
                Render Preview
              </button>
            </div>
          </div>

          {/* Preview Panel */}
          <div className="w-1/2 flex flex-col bg-slate-950">
            <div className="p-3 border-b border-slate-800 text-sm font-medium text-slate-400">
              Preview
            </div>
            <div className="flex-1 flex items-center justify-center p-4 overflow-auto">
              {error ? (
                <div className="text-red-400 text-center">
                  <AlertCircle size={32} className="mx-auto mb-2" />
                  <p className="text-sm">{error}</p>
                </div>
              ) : preview ? (
                <img
                  src={`data:image/png;base64,${preview}`}
                  alt="Map preview"
                  className="max-w-full max-h-full object-contain rounded-lg"
                />
              ) : (
                <div className="text-slate-500 text-center">
                  <Map size={48} className="mx-auto mb-3 opacity-30" />
                  <p>Click Render Preview to see your map</p>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="p-4 border-t border-slate-800 flex justify-end gap-3">
          <button
            onClick={onClose}
            className="px-4 py-2 bg-slate-700 hover:bg-slate-600 text-white rounded-lg transition-all"
          >
            Cancel
          </button>
          <button
            onClick={handleSave}
            disabled={!title.trim()}
            className="px-4 py-2 bg-indigo-600 hover:bg-indigo-500 text-white rounded-lg transition-all disabled:opacity-50"
          >
            Add Map
          </button>
        </div>
      </div>
    </div>
  );
};
