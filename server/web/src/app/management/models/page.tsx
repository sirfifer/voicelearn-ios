'use client';

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import {
  Cpu,
  Server,
  Volume2,
  Smartphone,
  Download,
  Zap,
  TrendingUp,
  ExternalLink,
} from 'lucide-react';

/**
 * AI Model Selection Dashboard
 *
 * Displays current and recommended AI models for UnaMentis across all use cases.
 * Updated: January 2026
 */

interface ModelInfo {
  name: string;
  version: string;
  releaseDate: string;
  size: string;
  parameters: string;
  performance: string;
  license: string;
  status: 'current' | 'recommended' | 'outdated';
  benchmarks?: { name: string; score: string }[];
  features: string[];
  deployment: string;
  url: string;
}

const onDeviceLLMs: ModelInfo[] = [
  {
    name: 'SmolLM3-3B',
    version: '3B',
    releaseDate: 'Dec 2025',
    size: '~1.5GB (Q4)',
    parameters: '3 billion',
    performance: 'Best-in-class for 3B models',
    license: 'Apache 2.0',
    status: 'recommended',
    benchmarks: [
      { name: 'MMLU', score: '~65%' },
      { name: 'HellaSwag', score: '1st/2nd place' },
      { name: 'ARC', score: '1st/2nd place' },
    ],
    features: [
      'Outperforms Llama 3.2 3B and Qwen2.5 3B',
      'Competitive with 4B models',
      'Strong knowledge and reasoning',
      'Reasoning mode available',
      'Fully open source (Hugging Face)',
    ],
    deployment: 'iPhone 12+ (A14+), Android 10+ with 4GB RAM',
    url: 'https://huggingface.co/blog/smollm3',
  },
  {
    name: 'Qwen3-1.7B',
    version: '1.7B',
    releaseDate: 'May 2025',
    size: '~900MB (Q4)',
    parameters: '1.7 billion',
    performance: 'Performs as well as Qwen2.5-3B-Base',
    license: 'Apache 2.0',
    status: 'recommended',
    benchmarks: [{ name: 'Density Improvement', score: '100% (vs Qwen2.5-3B)' }],
    features: [
      'Latest Qwen generation',
      'Significant density improvements',
      'Smaller size, comparable performance',
      'Multilingual support',
      'Official Alibaba release',
    ],
    deployment: 'iPhone XS+ (A12+), Android 8.0+ with 3GB RAM',
    url: 'https://qwenlm.github.io/',
  },
  {
    name: 'Llama 3.2 1B',
    version: '1B',
    releaseDate: 'Sept 2024',
    size: '~650MB (Q4)',
    parameters: '1 billion',
    performance: 'Outdated - surpassed by newer models',
    license: 'Llama 3 License',
    status: 'outdated',
    features: [
      'Original on-device optimization',
      'Wide hardware support',
      'Superseded by SmolLM3 and Qwen3',
    ],
    deployment: 'iPhone XS+, Android 8.0+ with 3GB RAM',
    url: 'https://llama.meta.com/',
  },
];

const serverLLMs: ModelInfo[] = [
  {
    name: 'Qwen3-235B-A22B-Instruct',
    version: '2507',
    releaseDate: 'May 2025',
    size: '~120GB',
    parameters: '235B total, 22B active (MoE)',
    performance: 'Top-tier instruction following',
    license: 'Apache 2.0',
    status: 'recommended',
    benchmarks: [
      { name: 'Instruction Following', score: 'Exceptional' },
      { name: 'Reasoning', score: 'State-of-the-art' },
      { name: 'Math & Science', score: 'Top-tier' },
      { name: 'Coding', score: 'Elite' },
    ],
    features: [
      'Latest Qwen generation (May 2025)',
      'MoE architecture for efficiency',
      'Exceptional instruction following',
      'Strong reasoning and comprehension',
      'Elite math, science, and coding',
      'Tool use capabilities',
    ],
    deployment: 'GPU server (A100/H100 recommended)',
    url: 'https://qwenlm.github.io/',
  },
  {
    name: 'GLM-4.7',
    version: '4.7',
    releaseDate: 'Late 2025',
    size: '~50GB',
    parameters: '~70B',
    performance: 'Best for code (91.2% SWE-bench)',
    license: 'Apache 2.0',
    status: 'recommended',
    benchmarks: [
      { name: 'SWE-bench', score: '91.2% (best)' },
      { name: 'Code Generation', score: 'Elite' },
    ],
    features: [
      'Best SWE-bench score (91.2%)',
      'Interleaved thinking architecture',
      'Preserves reasoning cache',
      'Thinks before responses',
      'Optimal for complex repositories',
    ],
    deployment: 'GPU server (A100 recommended)',
    url: 'https://github.com/THUDM/GLM-4',
  },
  {
    name: 'DeepSeek-V3.2',
    version: 'V3.2',
    releaseDate: 'Late 2025',
    size: '~140GB',
    parameters: '~671B total (MoE)',
    performance: 'Ties with GPT-4 on MMLU (94.2%)',
    license: 'MIT',
    status: 'recommended',
    benchmarks: [
      { name: 'MMLU', score: '94.2% (ties proprietary)' },
      { name: 'General Knowledge', score: 'Elite' },
    ],
    features: [
      'Matches proprietary models on MMLU',
      'Most reliable for education apps',
      'Exceptional general knowledge',
      'MoE architecture',
      'MIT license (very permissive)',
    ],
    deployment: 'GPU server (multi-GPU recommended)',
    url: 'https://github.com/deepseek-ai/DeepSeek-V3',
  },
];

const serverTTS: ModelInfo[] = [
  {
    name: 'Fish Speech V1.5',
    version: 'V1.5',
    releaseDate: 'Late 2025',
    size: '~2GB',
    parameters: 'DualAR Transformer',
    performance: 'Industry-leading (ELO 1339)',
    license: 'BSD-3-Clause',
    status: 'recommended',
    benchmarks: [
      { name: 'ELO Score', score: '1339' },
      { name: 'WER (English)', score: '3.5%' },
      { name: 'CER (English)', score: '1.2%' },
    ],
    features: [
      'DualAR architecture innovation',
      '300k+ hours English/Chinese training',
      '100k+ hours Japanese',
      'Exceptional multilingual support',
      'Industry-leading quality',
      'Low error rates',
    ],
    deployment: 'GPU server, CPU fallback available',
    url: 'https://speech.fish.audio/',
  },
  {
    name: 'Kyutai TTS 1.6B',
    version: '1.6B',
    releaseDate: 'July 2025',
    size: '~1.6GB',
    parameters: '1.6 billion',
    performance: 'Low-latency delayed streams',
    license: 'MIT',
    status: 'recommended',
    features: [
      'Delayed streams modeling',
      'Starts generating before full text input',
      'Ideal for voice assistants (low latency)',
      'English and French support',
      'Open source from Kyutai Labs',
      '220ms delay with Unmute wrapper',
    ],
    deployment: 'GPU server recommended',
    url: 'https://huggingface.co/kyutai/tts-1.6b-en_fr',
  },
  {
    name: 'IndexTTS-2',
    version: '2',
    releaseDate: 'Late 2025',
    size: '~1.5GB',
    parameters: 'Transformer-based',
    performance: 'Zero-shot with precise duration control',
    license: 'Apache 2.0',
    status: 'recommended',
    features: [
      'Zero-shot voice synthesis',
      'Precise duration control',
      'Emotional disentanglement',
      'Perfect for video dubbing',
      'Professional expressive speech',
      'Fine-grained timing control',
    ],
    deployment: 'GPU server recommended',
    url: 'https://github.com/alibaba-damo-academy/IndexTTS',
  },
  {
    name: 'VibeVoice-1.5B',
    version: '1.5B',
    releaseDate: 'Late 2025',
    size: '~3GB',
    parameters: '1.5 billion',
    performance: 'Long-form, multi-speaker generation',
    license: 'MIT',
    status: 'recommended',
    features: [
      'Microsoft official release',
      'Up to 90 minutes of speech',
      'Four distinct speakers',
      'Highly expressive',
      'Long-form content generation',
      'Multi-speaker scenarios',
    ],
    deployment: 'GPU server (moderate requirements)',
    url: 'https://aka.ms/vibevoice',
  },
];

const onDeviceTTS: ModelInfo[] = [
  {
    name: 'Kyutai Pocket TTS',
    version: '100M',
    releaseDate: 'Jan 13, 2026',
    size: '~100MB',
    parameters: '100 million',
    performance: 'Best WER (1.84%), sub-50ms latency',
    license: 'MIT',
    status: 'recommended',
    benchmarks: [
      { name: 'Word Error Rate', score: '1.84% (best)' },
      { name: 'Speed', score: '6x realtime (M4 CPU)' },
      { name: 'First Audio', score: '200ms' },
    ],
    features: [
      'Released Jan 13, 2026 (NEWEST)',
      'Best WER (1.84%) - beats 700M models',
      'Voice cloning from 5 seconds',
      'Sub-50ms latency',
      'CPU-only (no GPU needed)',
      '6x real-time on MacBook Air M4',
      '88,000 hours training data',
      'Full training code published',
      'CALM architecture',
    ],
    deployment: 'Any CPU - iPhone, Android, even low-end devices',
    url: 'https://kyutai.org/blog/2026-01-13-pocket-tts',
  },
  {
    name: 'NeuTTS Air',
    version: 'Air',
    releaseDate: 'Late 2025',
    size: '~500MB (GGUF)',
    parameters: '0.5 billion',
    performance: 'Super-realistic, instant voice cloning',
    license: 'Apache 2.0',
    status: 'recommended',
    features: [
      'On-device super-realistic TTS',
      'Instant voice cloning',
      '0.5B parameters',
      'Near-human speech quality',
      'Real-time performance',
      'GGUF/GGML format (llama.cpp compatible)',
      'Runs on CPU/GPU',
      'Works on Raspberry Pi',
    ],
    deployment: 'iPhone 12+, Android 10+, even Raspberry Pi',
    url: 'https://github.com/neuphonic/neutts',
  },
  {
    name: 'Kokoro-82M',
    version: '82M',
    releaseDate: 'Late 2025',
    size: '~80MB',
    parameters: '82 million',
    performance: 'Lightweight, high quality',
    license: 'Apache 2.0',
    status: 'recommended',
    features: [
      'Only 82M parameters',
      'Quality comparable to larger models',
      'Based on StyleTTS2 and ISTFTNet',
      'No encoders or diffusion (faster)',
      'Extremely efficient',
      'Cost-effective deployment',
    ],
    deployment: 'Any modern smartphone, very low requirements',
    url: 'https://github.com/kokoro-ai/kokoro',
  },
  {
    name: 'Apple Neural TTS',
    version: 'iOS 18+',
    releaseDate: '2024',
    size: 'Built-in',
    parameters: 'Unknown (proprietary)',
    performance: 'Efficient but limited quality',
    license: 'Proprietary',
    status: 'current',
    features: [
      'Built into iOS/macOS',
      'Zero download size',
      'Very efficient',
      'Limited naturalness',
      'Good fallback option',
      'Always available',
    ],
    deployment: 'All iOS/macOS devices',
    url: 'https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer',
  },
];

function StatusBadge({ status }: { status: ModelInfo['status'] }) {
  const variants = {
    current: 'default',
    recommended: 'default',
    outdated: 'secondary',
  } as const;

  const colors = {
    current: 'bg-blue-500',
    recommended: 'bg-green-500',
    outdated: 'bg-gray-400',
  } as const;

  return (
    <Badge variant={variants[status]} className={colors[status]}>
      {status === 'recommended' && <TrendingUp className="w-3 h-3 mr-1" />}
      {status.toUpperCase()}
    </Badge>
  );
}

function ModelCard({ model }: { model: ModelInfo }) {
  return (
    <Card className={model.status === 'recommended' ? 'border-green-500 border-2' : ''}>
      <CardHeader>
        <div className="flex items-start justify-between">
          <div>
            <CardTitle className="text-xl flex items-center gap-2">
              {model.name}
              <StatusBadge status={model.status} />
            </CardTitle>
            <CardDescription className="mt-1">
              Released: {model.releaseDate} • {model.license}
            </CardDescription>
          </div>
          <a
            href={model.url}
            target="_blank"
            rel="noopener noreferrer"
            className="text-blue-600 hover:text-blue-800"
          >
            <ExternalLink className="w-5 h-5" />
          </a>
        </div>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="grid grid-cols-2 gap-4 text-sm">
          <div>
            <div className="font-semibold flex items-center gap-1">
              <Download className="w-4 h-4" />
              Size
            </div>
            <div className="text-muted-foreground">{model.size}</div>
          </div>
          <div>
            <div className="font-semibold flex items-center gap-1">
              <Cpu className="w-4 h-4" />
              Parameters
            </div>
            <div className="text-muted-foreground">{model.parameters}</div>
          </div>
          <div className="col-span-2">
            <div className="font-semibold flex items-center gap-1">
              <Zap className="w-4 h-4" />
              Performance
            </div>
            <div className="text-muted-foreground">{model.performance}</div>
          </div>
          <div className="col-span-2">
            <div className="font-semibold">Deployment</div>
            <div className="text-muted-foreground text-xs">{model.deployment}</div>
          </div>
        </div>

        {model.benchmarks && model.benchmarks.length > 0 && (
          <div>
            <div className="font-semibold mb-2">Benchmarks</div>
            <div className="grid grid-cols-2 gap-2 text-sm">
              {model.benchmarks.map((bench) => (
                <div key={bench.name} className="bg-muted p-2 rounded">
                  <div className="font-medium">{bench.name}</div>
                  <div className="text-muted-foreground">{bench.score}</div>
                </div>
              ))}
            </div>
          </div>
        )}

        <div>
          <div className="font-semibold mb-2">Features</div>
          <ul className="text-sm space-y-1 list-disc list-inside text-muted-foreground">
            {model.features.map((feature, idx) => (
              <li key={idx}>{feature}</li>
            ))}
          </ul>
        </div>
      </CardContent>
    </Card>
  );
}

export default function ModelsPage() {
  return (
    <div className="container mx-auto p-6 space-y-6">
      <div>
        <h1 className="text-3xl font-bold mb-2">AI Model Selection Dashboard</h1>
        <p className="text-muted-foreground">
          Current and recommended AI models for UnaMentis (Updated: January 2026)
        </p>
        <p className="text-sm text-amber-600 mt-2">
          ⚠️ Models marked as OUTDATED should be replaced with RECOMMENDED alternatives
        </p>
      </div>

      <Tabs defaultValue="on-device-llm" className="space-y-4">
        <TabsList className="grid w-full grid-cols-4">
          <TabsTrigger value="on-device-llm" className="flex items-center gap-2">
            <Smartphone className="w-4 h-4" />
            On-Device LLM
          </TabsTrigger>
          <TabsTrigger value="server-llm" className="flex items-center gap-2">
            <Server className="w-4 h-4" />
            Server LLM
          </TabsTrigger>
          <TabsTrigger value="server-tts" className="flex items-center gap-2">
            <Volume2 className="w-4 h-4" />
            Server TTS
          </TabsTrigger>
          <TabsTrigger value="on-device-tts" className="flex items-center gap-2">
            <Smartphone className="w-4 h-4" />
            On-Device TTS
          </TabsTrigger>
        </TabsList>

        <TabsContent value="on-device-llm" className="space-y-6">
          <div className="bg-muted p-4 rounded-lg">
            <h3 className="font-semibold mb-2">Use Case: Knowledge Bowl Answer Validation</h3>
            <p className="text-sm text-muted-foreground">
              Small language model for on-device answer validation. Must run efficiently on iPhone
              12+ and Android 10+ devices. Target: 1-2GB quantized size, &lt;250ms inference
              latency, 95%+ accuracy.
            </p>
          </div>
          <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
            {onDeviceLLMs.map((model) => (
              <ModelCard key={model.name} model={model} />
            ))}
          </div>
        </TabsContent>

        <TabsContent value="server-llm" className="space-y-6">
          <div className="bg-muted p-4 rounded-lg">
            <h3 className="font-semibold mb-2">Use Case: AI Learning & Instruction Following</h3>
            <p className="text-sm text-muted-foreground">
              Large language model for interactive learning sessions. Must excel at instruction
              following, reasoning, and domain knowledge (math, science, history, literature).
              Deployed on GPU servers.
            </p>
          </div>
          <div className="grid gap-6 md:grid-cols-2">
            {serverLLMs.map((model) => (
              <ModelCard key={model.name} model={model} />
            ))}
          </div>
        </TabsContent>

        <TabsContent value="server-tts" className="space-y-6">
          <div className="bg-muted p-4 rounded-lg">
            <h3 className="font-semibold mb-2">Use Case: Pre-generated Learning Audio</h3>
            <p className="text-sm text-muted-foreground">
              High-quality text-to-speech for pre-generating learning content. Prioritizes
              naturalness, expressiveness, and multilingual support. Deployed on GPU servers for
              batch processing.
            </p>
          </div>
          <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
            {serverTTS.map((model) => (
              <ModelCard key={model.name} model={model} />
            ))}
          </div>
        </TabsContent>

        <TabsContent value="on-device-tts" className="space-y-6">
          <div className="bg-muted p-4 rounded-lg">
            <h3 className="font-semibold mb-2">Use Case: Interactive On-Device TTS Fallback</h3>
            <p className="text-sm text-muted-foreground">
              Lightweight text-to-speech for real-time interactive responses when server TTS is
              unavailable. Prioritizes efficiency and small size. Last resort fallback - most
              content will use pre-generated server TTS.
            </p>
          </div>
          <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
            {onDeviceTTS.map((model) => (
              <ModelCard key={model.name} model={model} />
            ))}
          </div>
        </TabsContent>
      </Tabs>

      <Card className="mt-6">
        <CardHeader>
          <CardTitle>Model Selection Guidelines</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <h4 className="font-semibold mb-2">For Server Administrators</h4>
            <ul className="text-sm space-y-1 list-disc list-inside text-muted-foreground">
              <li>Choose RECOMMENDED models for best performance and latest capabilities</li>
              <li>Models marked OUTDATED are superseded and should be migrated away from</li>
              <li>Consider hardware requirements when selecting server LLMs</li>
              <li>TTS models can often run on CPU for small batches, GPU for production scale</li>
              <li>
                On-device models must fit within mobile device constraints (1-2GB for LLM, &lt;500MB
                for TTS)
              </li>
            </ul>
          </div>
          <div>
            <h4 className="font-semibold mb-2">Implementation Status</h4>
            <ul className="text-sm space-y-1 text-muted-foreground">
              <li>
                ✅ <strong>On-Device LLM:</strong> Currently using Llama 3.2 1B (OUTDATED) - migrate
                to SmolLM3-3B or Qwen3-1.7B
              </li>
              <li>
                ⚠️ <strong>Server LLM:</strong> Needs selection and deployment
              </li>
              <li>
                ⚠️ <strong>Server TTS:</strong> Needs selection and deployment
              </li>
              <li>
                ✅ <strong>On-Device TTS:</strong> Using Apple Neural TTS (fallback) - UPGRADE to
                Kyutai Pocket TTS (100M, Jan 13 2026, best WER 1.84%)
              </li>
            </ul>
          </div>
          <div className="bg-amber-50 dark:bg-amber-950 p-4 rounded border border-amber-200 dark:border-amber-800">
            <h4 className="font-semibold mb-2 text-amber-900 dark:text-amber-100">
              Important: Model Updates
            </h4>
            <p className="text-sm text-amber-800 dark:text-amber-200">
              The AI model landscape evolves rapidly. This dashboard was last updated in January
              2026. Check release dates and benchmark sources regularly. New models may have been
              released since this page was created.
            </p>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
