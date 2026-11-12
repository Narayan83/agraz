import React, { useState } from "react";
import {
  CheckCircle2,
  Download,
  Folder,
  Loader2,
  NotebookPen,
  Phone,
  User,
} from "lucide-react";
import { registerBusinessPublic } from "../api/api";
import { MAIN_CATEGORIES } from "../lib/serviceCategories";
import "./PublicServiceRegister.css";

const emptyForm = () => ({
  name: "",
  mobile: "",
  main_category: "",
  description: "",
});

const PublicServiceRegister = () => {
  const [form, setForm] = useState(emptyForm);
  const [errors, setErrors] = useState({});
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState("");
  const [done, setDone] = useState(false);

  const setField = (key, value) => {
    setForm((prev) => ({ ...prev, [key]: value }));
    setErrors((prev) => ({ ...prev, [key]: "" }));
    setSubmitError("");
  };

  const validate = () => {
    const next = {};
    if (!form.name.trim()) next.name = "Required";
    const mobile = form.mobile.trim();
    if (!mobile) next.mobile = "Required";
    else if (!/^\d{10}$/.test(mobile)) next.mobile = "Enter a 10-digit mobile number";
    if (!form.main_category) next.main_category = "Required";
    if (!form.description.trim()) next.description = "Required";
    setErrors(next);
    return Object.keys(next).length === 0;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!validate()) return;

    setSubmitting(true);
    setSubmitError("");
    try {
      const name = form.name.trim();
      const payload = {
        mobile: form.mobile.trim(),
        name,
        main_category: form.main_category,
        business_name: name,
        remarks: form.description.trim(),
      };

      const data = await registerBusinessPublic(payload);
      if (data?.success === false) {
        setSubmitError(data.message || "Failed to register. Try again.");
        return;
      }
      setDone(true);
      setForm(emptyForm());
    } catch (err) {
      setSubmitError(
        err.response?.data?.error ||
          err.response?.data?.message ||
          "Failed to register. Please try again."
      );
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="psr-page">
      <header className="psr-hero">
        <div className="psr-logo">Ag</div>
        <div>
          <h1>Register your service</h1>
          <p>No login needed.</p>
        </div>
      </header>

      {done ? (
        <div className="psr-success">
          <CheckCircle2 size={40} />
          <h2>Service registered successfully</h2>
          <p>
            Your details were saved. The listing will appear in the app after it is approved.
          </p>
          <button type="button" className="psr-submit" onClick={() => setDone(false)}>
            Register another
          </button>
        </div>
      ) : (
        <form className="psr-form" onSubmit={handleSubmit} noValidate>
          {submitError && <div className="psr-alert">{submitError}</div>}

          <section className="psr-card">
            <label className="psr-field">
              <span>Name <em>*</em></span>
              <div className="psr-input">
                <User size={18} />
                <input
                  value={form.name}
                  onChange={(e) => setField("name", e.target.value)}
                  placeholder="Name"
                  autoComplete="name"
                />
              </div>
              {errors.name && <small>{errors.name}</small>}
            </label>
            <label className="psr-field">
              <span>Mobile Number <em>*</em></span>
              <div className="psr-input">
                <Phone size={18} />
                <input
                  value={form.mobile}
                  onChange={(e) => setField("mobile", e.target.value.replace(/\D/g, "").slice(0, 10))}
                  placeholder="10-digit mobile"
                  inputMode="numeric"
                  autoComplete="tel"
                />
              </div>
              {errors.mobile && <small>{errors.mobile}</small>}
            </label>
            <label className="psr-field">
              <span>Main Category <em>*</em></span>
              <div className="psr-input">
                <Folder size={18} />
                <select
                  value={form.main_category}
                  onChange={(e) => setField("main_category", e.target.value)}
                >
                  <option value="">Select main category</option>
                  {MAIN_CATEGORIES.map((c) => (
                    <option key={c} value={c}>{c}</option>
                  ))}
                </select>
              </div>
              {errors.main_category && <small>{errors.main_category}</small>}
            </label>
            <label className="psr-field">
              <span>Description <em>*</em></span>
              <div className="psr-input psr-input-top">
                <NotebookPen size={18} />
                <textarea
                  value={form.description}
                  onChange={(e) => setField("description", e.target.value)}
                  placeholder="Describe the service"
                  rows={2}
                />
              </div>
              {errors.description && <small>{errors.description}</small>}
            </label>
          </section>

          <button type="submit" className="psr-submit" disabled={submitting}>
            {submitting ? (
              <>
                <Loader2 className="psr-spin" size={20} /> Registering…
              </>
            ) : (
              "Register Service"
            )}
          </button>
        </form>
      )}

      <a
        className="psr-download"
        href="https://play.google.com/store/apps/details?id=com.agraz.app"
        target="_blank"
        rel="noopener noreferrer"
      >
        <Download size={18} />
        Download app
      </a>
    </div>
  );
};

export default PublicServiceRegister;
