import { useRef, useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { attachmentsApi } from "../api/tickets";
import type { AttachmentResponse } from "../types/ticket";
import axios from "axios";

const MAX_SIZE = 10 * 1024 * 1024; // 10MB

function formatBytes(bytes: number) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

export function AttachmentPanel({ ticketId }: { ticketId: string }) {
  const queryClient = useQueryClient();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);
  const [uploadError, setUploadError] = useState<string | null>(null);

  const { data: attachments, isLoading } = useQuery({
    queryKey: ["attachments", ticketId],
    queryFn: () => attachmentsApi.getAll(ticketId),
  });

  const deleteMutation = useMutation({
    mutationFn: (attachmentId: string) =>
      attachmentsApi.delete(ticketId, attachmentId),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ["attachments", ticketId] }),
  });

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setUploadError(null);

    if (file.size > MAX_SIZE) {
      setUploadError("File exceeds 10MB limit");
      return;
    }

    setUploading(true);
    try {
      // Step 1 — get pre-signed URL from Spring Boot
      const { uploadUrl, fileKey } = await attachmentsApi.initiate(ticketId, {
        fileName: file.name,
        mimeType: file.type || "application/octet-stream",
        fileSize: file.size,
      });

      // Step 2 — PUT directly to S3 (bypasses API Gateway entirely)
      await axios.put(uploadUrl, file, {
        headers: { "Content-Type": file.type || "application/octet-stream" },
      });

      // Step 3 — confirm with Spring Boot to save the DB record
      await attachmentsApi.confirm(ticketId, {
        fileName: file.name,
        mimeType: file.type || "application/octet-stream",
        fileSize: file.size,
        fileKey,
      });

      queryClient.invalidateQueries({ queryKey: ["attachments", ticketId] });
    } catch (err) {
      console.log("Error: ", err);
      setUploadError("Upload failed. Please try again.");
    } finally {
      setUploading(false);
      if (fileInputRef.current) fileInputRef.current.value = "";
    }
  };

  const handleDownload = async (attachment: AttachmentResponse) => {
    const url = await attachmentsApi.getDownloadUrl(ticketId, attachment.id);
    window.open(url, "_blank");
  };

  return (
    <div className="border-t border-gray-100 pt-4 mt-4">
      <div className="flex items-center justify-between mb-3">
        <p className="text-sm font-medium text-gray-700">Attachments</p>
        <button
          onClick={() => fileInputRef.current?.click()}
          disabled={uploading}
          className="text-xs bg-gray-100 hover:bg-gray-200 text-gray-700 px-3 py-1 rounded-lg disabled:opacity-50"
        >
          {uploading ? "Uploading..." : "+ Attach file"}
        </button>
        <input
          ref={fileInputRef}
          type="file"
          className="hidden"
          onChange={handleFileChange}
          accept="image/*,.pdf,.txt,.log,.zip,.csv"
        />
      </div>

      {uploadError && (
        <p className="text-red-500 text-xs mb-2">{uploadError}</p>
      )}

      {isLoading && (
        <p className="text-gray-400 text-sm">Loading attachments...</p>
      )}

      {attachments?.length === 0 && !isLoading && (
        <p className="text-gray-400 text-sm italic">No attachments yet</p>
      )}

      <div className="space-y-2">
        {attachments?.map((a) => (
          <div
            key={a.id}
            className="flex items-center justify-between bg-gray-50 rounded-lg px-3 py-2"
          >
            <div>
              <p className="text-sm text-gray-800">{a.fileName}</p>
              <p className="text-xs text-gray-400">
                {formatBytes(a.fileSize)} ·{" "}
                {new Date(a.uploadedAt).toLocaleDateString()}
              </p>
            </div>
            <div className="flex gap-2">
              <button
                onClick={() => handleDownload(a)}
                className="text-xs text-blue-600 hover:underline"
              >
                Download
              </button>
              <button
                onClick={() => deleteMutation.mutate(a.id)}
                className="text-xs text-red-400 hover:text-red-600"
              >
                Delete
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
