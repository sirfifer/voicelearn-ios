
import React, { useState, useEffect } from 'react';
import { RecursiveNode } from './RecursiveNode';
import { NodeEditor } from './NodeEditor';
import { Curriculum, ContentNode } from '@/types/curriculum';
import { BookOpen, Search, Menu, Command, Settings, ArrowLeft } from 'lucide-react';

interface CurriculumStudioProps {
    initialData: Curriculum;
    onSave: (data: Curriculum) => Promise<void>;
    onBack: () => void;
    readOnly?: boolean;
}

export const CurriculumStudio: React.FC<CurriculumStudioProps> = ({ initialData, onSave, onBack, readOnly = false }) => {
    const [curriculum, setCurriculum] = useState<Curriculum>(initialData);
    const [selectedNodeId, setSelectedNodeId] = useState<string | null>(
        initialData.content[0]?.id.value || null
    );
    const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);

    // Update local state if initialData changes
    useEffect(() => {
        setCurriculum(initialData);
        if (!selectedNodeId && initialData.content.length > 0) {
            setSelectedNodeId(initialData.content[0].id.value);
        }
    }, [initialData]);

    const isReadOnly = readOnly || !!curriculum.locked;

    // Helper to find node by ID recursively
    const findNode = (nodes: ContentNode[], id: string): ContentNode | null => {
        for (const node of nodes) {
            if (node.id.value === id) return node;
            if (node.children) {
                const found = findNode(node.children, id);
                if (found) return found;
            }
        }
        return null;
    };

    // Helper to update node by ID recursively
    const updateNode = (nodes: ContentNode[], updatedNode: ContentNode): ContentNode[] => {
        return nodes.map(node => {
            if (node.id.value === updatedNode.id.value) return updatedNode;
            if (node.children) {
                return { ...node, children: updateNode(node.children, updatedNode) };
            }
            return node;
        });
    };

    const handleNodeUpdate = (updatedNode: ContentNode) => {
        setCurriculum(prev => {
            const newContent = updateNode(prev.content, updatedNode);
            return { ...prev, content: newContent };
        });
    };

    const selectedNode = selectedNodeId ? findNode(curriculum.content, selectedNodeId) : null;

    return (
        <div className="flex h-[80vh] w-full bg-slate-950 text-slate-200 overflow-hidden font-sans border border-slate-800 rounded-lg shadow-2xl">

            {/* Mobile Header */}
            <div className="md:hidden absolute top-0 left-0 right-0 h-14 bg-slate-900 border-b border-slate-800 flex items-center px-4 z-50">
                <button onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)} className="p-2 text-slate-400 hover:text-white">
                    <Menu />
                </button>
                <span className="ml-3 font-semibold text-white">Curriculum Studio</span>
            </div>

            {/* Sidebar - Desktop & Mobile Drawer */}
            <div className={`
        absolute inset-y-0 left-0 z-40 w-80 bg-slate-900/95 backdrop-blur-xl border-r border-slate-800 flex flex-col transition-transform duration-300 ease-in-out md:translate-x-0 md:static md:bg-slate-900/50
        ${isMobileMenuOpen ? 'translate-x-0' : '-translate-x-full'}
      `}>
                <div className="p-4 border-b border-slate-800 flex items-center gap-3">
                    <button
                        onClick={onBack}
                        className="p-2 hover:bg-slate-800 rounded-lg transition-colors text-slate-400 hover:text-white -ml-2"
                        title="Exit Studio"
                    >
                        <ArrowLeft size={18} />
                    </button>
                    <div>
                        <h1 className="font-bold text-white tracking-tight truncate w-48">{curriculum.title}</h1>
                        <p className="text-xs text-slate-500">
                            v{curriculum.version.number} • {isReadOnly ? 'Locked' : 'Editing'}
                        </p>
                    </div>
                </div>

                <div className="p-3">
                    <div className="relative">
                        <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500 h-4 w-4" />
                        <input
                            className="w-full bg-slate-800/50 border border-slate-700/50 rounded-lg py-2 pl-9 pr-3 text-sm text-slate-300 placeholder:text-slate-600 focus:outline-none focus:ring-1 focus:ring-indigo-500/50 transition-all"
                            placeholder="Filter content..."
                        />
                    </div>
                </div>

                <div className="flex-1 overflow-y-auto custom-scrollbar p-2">
                    <div className="mb-2 px-2 text-xs font-bold text-slate-500 uppercase tracking-wider">Structure</div>
                    {curriculum.content.map(node => (
                        <RecursiveNode
                            key={node.id.value}
                            node={node}
                            selectedId={selectedNodeId}
                            onSelect={(n) => {
                                setSelectedNodeId(n.id.value);
                                setIsMobileMenuOpen(false);
                            }}
                        />
                    ))}
                </div>

                <div className="p-4 border-t border-slate-800 bg-slate-900/80">
                    <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-full bg-gradient-to-tr from-indigo-500 to-purple-500 flex items-center justify-center text-xs font-bold text-white">
                            Edit
                        </div>
                        <div className="flex-1 overflow-hidden">
                            <div className="text-sm font-medium text-white truncate">{isReadOnly ? 'Read Only Mode' : 'Studio Mode'}</div>
                            <div className="text-xs text-slate-500">{isReadOnly ? 'Changes disabled' : 'Auto-saving enabled'}</div>
                        </div>
                        <button className="text-slate-500 hover:text-white transition-colors">
                            <Settings size={16} />
                        </button>
                    </div>
                </div>
            </div>

            {/* Mobile Overlay */}
            {isMobileMenuOpen && (
                <div
                    className="absolute inset-0 bg-black/50 z-30 md:hidden backdrop-blur-sm"
                    onClick={() => setIsMobileMenuOpen(false)}
                />
            )}

            {/* Main Content */}
            <div className="flex-1 flex flex-col min-w-0 bg-slate-950 relative pt-14 md:pt-0">
                {selectedNode ? (
                    <NodeEditor
                        key={selectedNode.id.value}
                        node={selectedNode}
                        onChange={handleNodeUpdate}
                        readOnly={isReadOnly}
                    />
                ) : (
                    <div className="flex-1 flex flex-col items-center justify-center text-slate-500">
                        <Command size={48} className="mb-4 opacity-20" />
                        <p>Select a node from the sidebar to start editing</p>
                    </div>
                )}
            </div>
        </div>
    );
};
